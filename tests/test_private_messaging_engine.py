"""Engine-level private messaging migration tests.

These prove FriendsEngine chooses the standards-based transport for capable
peers, retains upgrade compatibility for old peers, and keeps group metadata
inside the encrypted NIP-59 envelope.
"""

import json
import base64
import hashlib
import os
import shutil
import socket
import socketserver
import sqlite3
import struct
import tempfile
import threading
import unittest
import zipfile
from contextlib import closing, redirect_stdout
from types import SimpleNamespace
from io import BytesIO, StringIO
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


BIN_DIR = Path(__file__).parent.parent / "bin"
friends = SourceFileLoader(
    "friends_engine_private_transport", str(BIN_DIR / "omarchy-friends")
).load_module()


class LoopbackNostrRelay:
    """Minimal localhost Nostr relay for real WebSocket messaging tests."""

    class Handler(socketserver.BaseRequestHandler):
        def setup(self):
            self.rfile = self.request.makefile("rb")

        def handle(self):
            try:
                request_line = self.rfile.readline(16384)
                headers = {}
                while True:
                    line = self.rfile.readline(16384)
                    if not line or line in (b"\r\n", b"\n"):
                        break
                    if b":" in line:
                        name, value = line.split(b":", 1)
                        headers[name.decode("latin1").strip().lower()] = value.decode("latin1").strip()
                key = headers.get("sec-websocket-key", "")
                if not request_line.startswith(b"GET ") or not key:
                    return
                accept = base64.b64encode(hashlib.sha1(
                    (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")
                ).digest()).decode("ascii")
                self.request.sendall((
                    "HTTP/1.1 101 Switching Protocols\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
                ).encode("ascii"))
                while True:
                    message = self._read_json_frame()
                    if message is None:
                        return
                    if not message:
                        continue
                    if message[0] == "EVENT" and len(message) == 2:
                        event = message[1]
                        with self.server.events_lock:
                            self.server.events[event["id"]] = event
                        self._send_json(["OK", event["id"], True, "stored on loopback test relay"])
                    elif message[0] == "REQ" and len(message) >= 3:
                        sub_id, filters = message[1], message[2:]
                        with self.server.events_lock:
                            events = list(self.server.events.values())
                        for event in events:
                            if any(self._matches(event, filter_) for filter_ in filters if isinstance(filter_, dict)):
                                self._send_json(["EVENT", sub_id, event])
                        self._send_json(["EOSE", sub_id])
                    elif message[0] == "CLOSE":
                        continue
            except (BrokenPipeError, ConnectionError, OSError, ValueError, json.JSONDecodeError):
                return

        @staticmethod
        def _matches(event, filter_):
            if "kinds" in filter_ and event.get("kind") not in filter_["kinds"]:
                return False
            if "authors" in filter_ and event.get("pubkey") not in filter_["authors"]:
                return False
            if "since" in filter_ and event.get("created_at", 0) < filter_["since"]:
                return False
            tags = event.get("tags", [])
            for name, values in filter_.items():
                if not name.startswith("#"):
                    continue
                tag_name = name[1:]
                if not any(len(tag) >= 2 and tag[0] == tag_name and tag[1] in values for tag in tags):
                    return False
            return True

        def _read_exact(self, count):
            data = self.rfile.read(count)
            if len(data) != count:
                raise EOFError("client closed loopback WebSocket")
            return data

        def _read_json_frame(self):
            first, second = self._read_exact(2)
            opcode = first & 0x0F
            if opcode == 8:
                return None
            length = second & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._read_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._read_exact(8))[0]
            if length > 4 * 1024 * 1024:
                raise ValueError("loopback test relay frame too large")
            mask = self._read_exact(4) if second & 0x80 else None
            payload = self._read_exact(length)
            if mask:
                payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
            if opcode == 9:
                self._send_frame(10, payload)
                return []
            if opcode != 1:
                return []
            return json.loads(payload.decode("utf-8"))

        def _send_json(self, message):
            self._send_frame(1, json.dumps(message, separators=(",", ":")).encode("utf-8"))

        def _send_frame(self, opcode, payload):
            length = len(payload)
            header = bytes((0x80 | opcode, length)) if length < 126 else (
                bytes((0x80 | opcode, 126)) + struct.pack("!H", length)
                if length < 65536 else bytes((0x80 | opcode, 127)) + struct.pack("!Q", length)
            )
            self.request.sendall(header + payload)

    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

        def __init__(self):
            super().__init__(("127.0.0.1", 0), LoopbackNostrRelay.Handler)
            self.events = {}
            self.events_lock = threading.Lock()

    def __enter__(self):
        self.server = self.Server()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"ws://127.0.0.1:{self.server.server_address[1]}"
        return self

    def __exit__(self, *_args):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)


class PrivateMessagingEngineTests(unittest.TestCase):
    def setUp(self):
        self.paths = [tempfile.mkdtemp() for _ in range(3)]
        self.alice = friends.FriendsEngine(state_dir=self.paths[0])
        self.bob = friends.FriendsEngine(state_dir=self.paths[1])
        self.carol = friends.FriendsEngine(state_dir=self.paths[2])
        # Persist generated identities first so subsequent fixture writes use
        # the same merge baseline as a normally initialized installation.
        self.alice.save_state()
        self.bob.save_state()
        self.carol.save_state()

    def tearDown(self):
        for path in self.paths:
            shutil.rmtree(path, ignore_errors=True)

    @staticmethod
    def key(engine):
        return engine.state["global_identity"]["public_key"]

    def test_conversation_history_pages_are_bounded_scoped_and_chronological(self):
        friend_key = self.key(self.bob)
        other_key = self.key(self.carol)
        own_key = self.key(self.alice)
        group_id = "group-history-test"
        for index in range(3):
            self.alice.state["global"]["messages"].append({
                "id": f"{index + 1:064x}",
                "public_key": own_key,
                "conversation_key": friend_key,
                "text": f"friend message {index}",
                "timestamp": index + 1,
                "incoming": False,
            })
        self.alice.state["global"]["messages"].extend([
            {
                "id": "a" * 64,
                "public_key": own_key,
                "conversation_key": other_key,
                "text": "another friend's message",
                "timestamp": 4,
                "incoming": False,
            },
            {
                "id": "b" * 64,
                "public_key": own_key,
                "conversation_key": "",
                "group_id": group_id,
                "text": "group message",
                "timestamp": 5,
                "incoming": False,
            },
        ])

        latest = self.alice.conversation_history_page("friend", friend_key, 0, 2)
        self.assertTrue(latest["ok"])
        self.assertEqual(latest["total"], 3)
        self.assertTrue(latest["has_earlier"])
        self.assertEqual([item["text"] for item in latest["messages"]], ["friend message 1", "friend message 2"])

        earlier = self.alice.conversation_history_page("friend", friend_key, 2, 2)
        self.assertFalse(earlier["has_earlier"])
        self.assertEqual([item["text"] for item in earlier["messages"]], ["friend message 0"])

        group = self.alice.conversation_history_page("group", group_id, 0, 500)
        self.assertEqual([item["text"] for item in group["messages"]], ["group message"])
        self.assertLessEqual(len(group["messages"]), friends.MAX_CONVERSATION_HISTORY_PAGE_SIZE)
        self.assertFalse(self.alice.conversation_history_page("friend", "invalid", 0, 80)["ok"])
        output = StringIO()
        with patch.object(friends, "FriendsEngine", return_value=self.alice), \
                patch.object(friends.sys, "argv", ["omarchy-friends", "conversation-history", "friend", friend_key, "2", "2"]), \
                redirect_stdout(output):
            friends.main()
        cli_result = json.loads(output.getvalue())
        self.assertEqual([item["text"] for item in cli_result["messages"]], ["friend message 0"])

    def test_manual_private_history_sync_recovers_old_gifts_without_notifications(self):
        self.make_friends(self.alice, self.bob)
        old_timestamp = friends.now_seconds() - 30 * 86400
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"],
            [self.key(self.bob)],
            "message from last month",
            app_envelope={"v": 3, "type": "direct", "text": "message from last month"},
            created_at=old_timestamp,
        )
        gift = friends.wrap_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor
        )
        forged_duplicate_id = dict(gift, content="not a valid NIP-59 ciphertext")

        class HistoryRelay:
            instances = []

            def __init__(self, url, timeout=8.0):
                self.url = url
                self.sent = []
                self.subscription = ""
                self.next_event = 0
                self.sent_eose = False
                self.__class__.instances.append(self)

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def send_json(self, message):
                self.sent.append(message)
                if message[0] == "REQ":
                    self.subscription = message[1]

            def recv_json(self, _timeout=None):
                if self.next_event == 0:
                    self.next_event += 1
                    return ["EVENT", self.subscription, forged_duplicate_id]
                if self.next_event == 1:
                    self.next_event += 1
                    return ["EVENT", self.subscription, gift]
                if not self.sent_eose:
                    self.sent_eose = True
                    return ["EOSE", self.subscription]
                return None

        relay_urls = ("wss://history-one.invalid", "wss://history-two.invalid")
        with patch.object(friends, "NIP17_DM_RELAYS", relay_urls), patch.object(
            friends, "WebSocketClient", HistoryRelay
        ):
            ok, message, restored, checked, completed = self.bob.sync_private_history()

        self.assertTrue(ok, message)
        self.assertEqual((restored, checked, completed), (1, 2, 2))
        history = self.bob.conversation_history_page("friend", self.key(self.alice), 0, 80)
        self.assertEqual([item["text"] for item in history["messages"]], ["message from last month"])
        restored_message = history["messages"][0]
        self.assertEqual(restored_message["received_at_ms"], old_timestamp * 1000)
        self.assertFalse(any(item.get("kind") == "dm" for item in self.bob.state["events"]))
        for relay in HistoryRelay.instances:
            request = next(message for message in relay.sent if message[0] == "REQ")
            self.assertNotIn("since", request[2])
            self.assertNotIn("until", request[2])
            self.assertEqual(request[2]["limit"], friends.MAX_RELAY_DM_MESSAGES)

        with patch.object(friends, "NIP17_DM_RELAYS", relay_urls), patch.object(
            friends, "WebSocketClient", HistoryRelay
        ):
            ok, _message, restored_again, _checked, _completed = self.bob.sync_private_history()
        self.assertTrue(ok)
        self.assertEqual(restored_again, 0)
        self.assertEqual(self.bob.conversation_history_page("friend", self.key(self.alice), 0, 80)["total"], 1)

        output = StringIO()
        with patch.object(friends, "FriendsEngine", return_value=self.bob), \
                patch.object(self.bob, "sync_private_history", return_value=(True, "checked", 0, 3, 2)), \
                patch.object(friends.sys, "argv", ["omarchy-friends", "sync-private-history"]), \
                redirect_stdout(output):
            friends.main()
        cli_result = json.loads(output.getvalue())
        self.assertEqual(cli_result["completed_relays"], 2)
        self.assertEqual(cli_result["checked_relays"], 3)

    def test_manual_private_history_sync_advances_through_older_relay_pages(self):
        self.make_friends(self.alice, self.bob)
        relay_url = friends.GLOBAL_RELAYS[0]
        events = [
            {"id": f"{index:064x}", "kind": friends.NIP59_GIFT_WRAP_KIND, "created_at": timestamp}
            for index, timestamp in ((1, 300), (2, 200), (3, 100))
        ]
        messages = {
            event["id"]: {
                "id": event["id"],
                "public_key": self.key(self.alice),
                "conversation_key": self.key(self.alice),
                "handle": "Alice",
                "text": f"page message {event['created_at']}",
                "timestamp": event["created_at"],
                "incoming": True,
                "message_type": "direct",
            }
            for event in events
        }
        calls = []

        def fetch(_relay_url, _own_key, until=None):
            calls.append(until)
            if until is None:
                return events[:2], False
            self.assertEqual(until, 199)
            return events[2:], True

        with patch.object(friends, "NIP17_DM_RELAYS", (relay_url,)), \
                patch.object(friends, "MAX_RELAY_DM_MESSAGES", 2), \
                patch.object(self.bob, "_fetch_private_history_from_relay", side_effect=fetch), \
                patch.object(self.bob, "_global_dm_from_event", side_effect=lambda event: messages.get(event["id"])):
            ok, _message, restored, checked, completed = self.bob.sync_private_history()
            self.assertTrue(ok)
            self.assertEqual((restored, checked, completed), (2, 1, 0))
            self.assertEqual(self.bob.state["global"]["private_history_cursors"][relay_url], {"until": 199, "done": False})

            ok, _message, restored, checked, completed = self.bob.sync_private_history()
            self.assertTrue(ok)
            self.assertEqual((restored, checked, completed), (1, 1, 1))

        self.assertEqual(calls, [None, 199])
        self.assertEqual(
            self.bob.state["global"]["private_history_cursors"][relay_url],
            {"until": 199, "done": True},
        )
        history = self.bob.conversation_history_page("friend", self.key(self.alice), 0, 80)
        self.assertEqual([item["text"] for item in history["messages"]], ["page message 100", "page message 200", "page message 300"])

    def test_conversation_history_includes_legacy_direct_rows_without_conversation_key(self):
        friend_key = self.key(self.bob)
        other_key = self.key(self.carol)
        self.alice.state["global"]["messages"].extend([
            {
                "id": "c" * 64,
                "public_key": friend_key,
                "conversation_key": "",
                "text": "legacy incoming row",
                "timestamp": 2,
                "incoming": True,
            },
            {
                "id": "d" * 64,
                "public_key": friend_key,
                "conversation_key": "",
                "text": "legacy outgoing row",
                "timestamp": 1,
                "incoming": False,
            },
            {
                "id": "e" * 64,
                "public_key": other_key,
                "conversation_key": "",
                "text": "another peer legacy row",
                "timestamp": 3,
                "incoming": True,
            },
        ])

        page = self.alice.conversation_history_page("friend", friend_key, 0, 80)
        self.assertTrue(page["ok"])
        self.assertEqual(page["total"], 2)
        self.assertEqual([item["text"] for item in page["messages"]], ["legacy outgoing row", "legacy incoming row"])

    def test_ui_status_keeps_only_latest_message_preview_per_conversation(self):
        own_key = self.key(self.alice)
        peer_key = self.key(self.bob)
        status = {
            "profile": {"public_key": own_key},
            "global_messages": [
                {"id": "1", "public_key": peer_key, "conversation_key": "", "timestamp": 1},
                {"id": "2", "public_key": peer_key, "conversation_key": "", "timestamp": 2},
                {"id": "3", "public_key": own_key, "conversation_key": "", "timestamp": 3},
                {"id": "4", "public_key": own_key, "conversation_key": peer_key, "timestamp": 4},
                {"id": "5", "group_id": "group-a", "timestamp": 5},
                {"id": "6", "group_id": "group-a", "timestamp": 6},
            ],
        }
        with patch.object(self.alice, "get_full_status", return_value=json.loads(json.dumps(status))):
            compact = self.alice.get_ui_status()

        self.assertEqual([item["id"] for item in compact["global_messages"]], ["4", "6"])
        self.assertEqual(compact["global_message_counts"], {"friend:" + peer_key: 3, "group:group-a": 2})
        self.assertEqual(len(status["global_messages"]), 6)

    def test_local_message_search_returns_latest_thread_match_and_history_offset(self):
        own_key = self.key(self.alice)
        peer_key = self.key(self.bob)
        status = {
            "profile": {"public_key": own_key},
            "global_messages": [
                {"id": "1", "public_key": peer_key, "text": "needle older", "timestamp": 1, "incoming": True},
                {"id": "2", "public_key": peer_key, "text": "ordinary", "timestamp": 2, "incoming": True},
                {"id": "3", "public_key": peer_key, "text": "needle newest", "timestamp": 3, "incoming": False},
                {"id": "4", "public_key": own_key, "text": "needle own thread", "timestamp": 4},
                {"id": "5", "public_key": own_key, "group_id": "group-a", "text": "needle group", "timestamp": 5},
            ],
        }
        self.alice.state["global"]["messages"] = status["global_messages"]
        result = self.alice.search_messages("NEEDLE")

        self.assertTrue(result["ok"])
        self.assertEqual([item["id"] for item in result["messages"]], ["5", "3"])
        self.assertEqual(result["messages"][1]["history_offset"], 0)

    def test_keyed_journal_index_serves_compact_status_and_selected_history(self):
        peer_key = self.key(self.bob)
        other_key = self.key(self.carol)
        own_key = self.key(self.alice)
        self.alice.state["global"]["messages"] = [
            {"id": f"{1:064x}", "public_key": peer_key, "handle": "Friend", "text": "private preview one", "timestamp": 1, "incoming": True},
            {"id": f"{2:064x}", "public_key": peer_key, "handle": "Friend", "text": "private preview two", "timestamp": 2, "incoming": False},
            {"id": f"{3:064x}", "public_key": other_key, "handle": "Other", "text": "other private text", "timestamp": 3, "incoming": True},
            {"id": f"{4:064x}", "public_key": own_key, "conversation_key": "", "handle": "Old profile", "text": "unlinked saved message", "timestamp": 4, "incoming": False},
        ]
        self.alice.save_state()

        raw_db = self.alice.message_journal_file.read_bytes()
        self.assertNotIn(b"private preview", raw_db)
        self.assertNotIn(peer_key.encode(), raw_db)
        with closing(sqlite3.connect(self.alice.message_journal_file)) as db:
            tokens = [row[0] for row in db.execute("SELECT conversation_token FROM messages")]
            self.assertEqual(len(set(tokens)), 3)
            self.assertNotIn(peer_key, tokens)
            legacy_rows = db.execute("SELECT message_key,payload FROM messages").fetchall()
            db.execute("DROP TABLE messages")
            db.execute("DROP TABLE conversation_index")
            db.execute("DROP TABLE journal_meta")
            db.execute("CREATE TABLE messages (message_key TEXT PRIMARY KEY, payload BLOB NOT NULL)")
            db.executemany("INSERT INTO messages(message_key,payload) VALUES(?,?)", legacy_rows)
            db.commit()

        readonly = friends.FriendsEngine(state_dir=self.paths[0], load_message_journal=False)
        self.assertEqual(readonly.state["global"].get("messages", []), [])
        state_mtime = readonly.state_file.stat().st_mtime_ns
        with patch.object(readonly, "_decrypt_message_payload", wraps=readonly._decrypt_message_payload) as decrypt:
            status = readonly.get_ui_status()
            self.assertEqual(decrypt.call_count, 7)  # one-time migration plus one latest row per conversation
        self.assertEqual(status["global_message_counts"]["friend:" + peer_key], 2)
        self.assertEqual(status["global_message_counts"]["unlinked:local"], 1)
        self.assertEqual(len(status["global_messages"]), 3)
        unlinked_preview = next(item for item in status["global_messages"] if item.get("legacy_unlinked"))
        self.assertEqual(unlinked_preview["text"], "unlinked saved message")
        self.assertEqual(readonly.state_file.stat().st_mtime_ns, state_mtime)

        with patch.object(readonly, "_decrypt_message_payload", wraps=readonly._decrypt_message_payload) as decrypt:
            readonly.get_ui_status()
            self.assertEqual(decrypt.call_count, 3)  # steady-state status decrypts one row per conversation

        with patch.object(readonly, "_decrypt_message_payload", wraps=readonly._decrypt_message_payload) as decrypt:
            page = readonly.conversation_history_page("friend", peer_key, 0, 80)
        self.assertEqual(decrypt.call_count, 2)  # rows from the selected thread only
        self.assertEqual([item["text"] for item in page["messages"]], ["private preview one", "private preview two"])

        with patch.object(readonly, "_decrypt_message_payload", wraps=readonly._decrypt_message_payload) as decrypt:
            recovered = readonly.conversation_history_page("unlinked", "local", 0, 80)
            self.assertEqual(decrypt.call_count, 1)
        self.assertEqual(recovered["total"], 1)
        self.assertTrue(recovered["messages"][0]["legacy_unlinked"])
        self.assertEqual(recovered["messages"][0]["text"], "unlinked saved message")

    def test_partial_journal_snapshot_never_deletes_omitted_chat_messages(self):
        peer_key = self.key(self.bob)
        messages = [
            {
                "id": f"{index:064x}",
                "public_key": peer_key,
                "conversation_key": peer_key,
                "handle": "Friend",
                "text": f"preserve {index}",
                "timestamp": index,
                "incoming": True,
            }
            for index in (1, 2)
        ]
        self.alice.state["global"]["messages"] = messages
        self.alice.save_state()

        # Simulate a stale or partial writer. Missing IDs alone must not be
        # interpreted as a user request to delete saved chat history.
        self.alice._write_message_journal_locked([messages[0]], peer_key)
        with closing(sqlite3.connect(self.alice.message_journal_file)) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM messages").fetchone()[0], 2)

        restored = friends.FriendsEngine(state_dir=self.paths[0])
        history = restored.conversation_history_page("friend", peer_key, 0, 80)
        self.assertEqual([item["text"] for item in history["messages"]], ["preserve 1", "preserve 2"])

    def test_send_commands_return_saved_message_id_even_when_delivery_needs_retry(self):
        target_id = "a" * 64
        engine = SimpleNamespace(
            last_sent_message_id=target_id,
            state={"global": {"messages": [{"id": target_id, "sendState": "Unconfirmed · retry"}]}},
            send_dm=lambda *args: (False, "Delivery is unconfirmed; retry is available"),
            retry_pending_private_messages=lambda: (1, 1),
        )
        def fake_send_group(*args):
            engine.state["global"]["messages"][0]["sendState"] = "Partial · retry"
            return False, "Delivery confirmed for 1 of 2 members; retry the rest"
        engine.send_group_message = fake_send_group
        direct_output = StringIO()
        with patch.object(friends, "FriendsEngine", return_value=engine), \
                patch.object(friends.sys, "argv", ["omarchy-friends", "send-dm", "b" * 64, '{"text":"direct"}']), \
                redirect_stdout(direct_output):
            friends.main()
        direct_result = json.loads(direct_output.getvalue())
        self.assertFalse(direct_result["ok"])
        self.assertEqual(direct_result["message_id"], target_id)
        self.assertEqual(direct_result["send_state"], "Unconfirmed · retry")

        group_output = StringIO()
        with patch.object(friends, "FriendsEngine", return_value=engine), \
                patch.object(friends.sys, "argv", ["omarchy-friends", "send-group", "group-id", '{"text":"group"}']), \
                redirect_stdout(group_output):
            friends.main()
        group_result = json.loads(group_output.getvalue())
        self.assertFalse(group_result["ok"])
        self.assertEqual(group_result["message_id"], target_id)
        self.assertEqual(group_result["send_state"], "Partial · retry")

        retry_output = StringIO()
        with patch.object(friends, "FriendsEngine", return_value=engine), \
                patch.object(friends.sys, "argv", ["omarchy-friends", "retry-pending-messages"]), \
                redirect_stdout(retry_output):
            friends.main()
        retry_result = json.loads(retry_output.getvalue())
        self.assertTrue(retry_result["ok"])
        self.assertEqual((retry_result["attempted"], retry_result["delivered"]), (1, 1))

    def test_private_chat_burst_has_its_own_bounded_rate_limit(self):
        sender = self.key(self.bob)
        now = friends.now_seconds()
        self.alice.state["global"]["incoming_receipts"] = [
            {"public_key": sender, "timestamp": now, "category": "signal"}
            for _ in range(friends.MAX_INCOMING_SIGNALS_PER_MINUTE)
        ]
        self.assertFalse(self.alice._allow_global_signal(sender))
        self.assertTrue(self.alice._allow_global_signal(sender, category="private"))
        self.alice.state["global"]["incoming_receipts"] = [
            {"public_key": sender, "timestamp": now, "category": "private"}
            for _ in range(friends.MAX_INCOMING_PRIVATE_MESSAGES_PER_MINUTE)
        ]
        self.assertFalse(self.alice._allow_global_signal(sender, category="private"))
        self.assertTrue(self.alice._allow_global_signal(sender, category="signal"))

    def test_private_safety_code_is_order_independent_and_rejects_bad_keys(self):
        alice_key = self.key(self.alice)
        bob_key = self.key(self.bob)
        carol_key = self.key(self.carol)
        code = friends.derive_private_safety_code(alice_key, bob_key)
        self.assertEqual(code, friends.derive_private_safety_code(bob_key, alice_key))
        self.assertEqual(len(code.replace(" ", "")), 64)
        self.assertEqual(len(code.split()), 8)
        self.assertNotEqual(code, friends.derive_private_safety_code(alice_key, carol_key))
        with self.assertRaises(ValueError):
            friends.derive_private_safety_code(alice_key, bob_key + "0")

    def test_safety_code_command_returns_only_the_pairwise_fingerprint(self):
        alice_key = self.key(self.alice)
        bob_key = self.key(self.bob)
        output = StringIO()
        fake_engine = SimpleNamespace(_global_identity=lambda: {"public_key": alice_key})
        with patch.object(friends, "FriendsEngine", return_value=fake_engine):
            with patch("sys.argv", [str(BIN_DIR / "omarchy-friends"), "safety-code", bob_key]):
                with patch("sys.stdout", output):
                    friends.main()
        result = json.loads(output.getvalue())
        self.assertTrue(result["ok"])
        self.assertEqual(result["safety_code"], friends.derive_private_safety_code(alice_key, bob_key))
        self.assertNotIn(alice_key, output.getvalue())
        self.assertNotIn(bob_key, output.getvalue())

    def test_private_rate_limit_category_survives_state_reload(self):
        sender = self.key(self.bob)
        now = friends.now_seconds()
        self.alice.state["global"]["incoming_receipts"] = [
            {"public_key": sender, "timestamp": now, "category": "private"}
        ]
        self.alice.save_state()
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertEqual(restored.state["global"]["incoming_receipts"][0]["category"], "private")

    def test_nip17_dm_round_trips_over_loopback_websocket_relay(self):
        """Exercise actual WebSocket discovery, publish, subscription, decrypt, and dedupe locally."""
        self.make_friends(self.alice, self.bob)
        for viewer, peer in ((self.alice, self.bob), (self.bob, self.alice)):
            viewer.state["global"]["peers"][self.key(peer)] = {
                "public_key": self.key(peer),
                "capabilities": list(friends.GLOBAL_CAPABILITIES),
            }

        with LoopbackNostrRelay() as relay:
            with patch.object(friends, "GLOBAL_RELAYS", (relay.url,)):
                with patch.object(friends, "NIP17_DM_RELAYS", (relay.url,)):
                    # Bob advertises his inbox. Alice must discover it over a
                    # real WebSocket REQ before she can publish the gift wrap.
                    bob_list = self.bob._dm_relay_list_event()
                    published, _ = self.bob._publish_event_to_relays(bob_list, [relay.url])
                    self.assertTrue(published)

                    ok, result = self.alice.send_dm(self.key(self.bob), "loopback private payload")
                    self.assertTrue(ok, result)
                    self.assertEqual(len(self.alice.state["global"]["messages"]), 1)
                    self.assertEqual(
                        self.alice.state["global"]["messages"][0]["sendState"],
                        "Sent",
                    )

                    ok, _ = self.bob.sync_global()
                    self.assertTrue(ok)
                    received = [
                        message for message in self.bob.state["global"]["messages"]
                        if message.get("incoming")
                    ]
                    self.assertEqual(len(received), 1)
                    self.assertEqual(received[0]["text"], "loopback private payload")

                    ok, _ = self.bob.sync_global()
                    self.assertTrue(ok)
                    received_again = [
                        message for message in self.bob.state["global"]["messages"]
                        if message.get("incoming")
                    ]
                    self.assertEqual(len(received_again), 1)

                    with relay.server.events_lock:
                        gifts = [
                            event for event in relay.server.events.values()
                            if event.get("kind") == friends.NIP59_GIFT_WRAP_KIND
                        ]
                    self.assertEqual(len(gifts), 1)
                    serialized_gift = json.dumps(gifts[0], sort_keys=True)
                    self.assertNotIn(self.key(self.alice), serialized_gift)
                    self.assertNotIn("loopback private payload", serialized_gift)

    def test_nip17_group_invite_and_message_round_trip_over_loopback_relay(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        for viewer, peer in (
            (self.alice, self.bob), (self.bob, self.alice),
            (self.alice, self.carol), (self.carol, self.alice),
        ):
            viewer.state["global"]["peers"][self.key(peer)] = {
                "public_key": self.key(peer),
                "capabilities": list(friends.GLOBAL_CAPABILITIES),
            }

        with LoopbackNostrRelay() as relay:
            with patch.object(friends, "GLOBAL_RELAYS", (relay.url,)):
                with patch.object(friends, "NIP17_DM_RELAYS", (relay.url,)):
                    for peer in (self.bob, self.carol):
                        published, _ = peer._publish_event_to_relays(
                            peer._dm_relay_list_event(), [relay.url]
                        )
                        self.assertTrue(published)

                    created, result = self.alice.create_group(
                        "Loopback team", [self.key(self.bob), self.key(self.carol)]
                    )
                    self.assertTrue(created, result)
                    group = next(iter(self.alice.state["global"]["groups"].values()))

                    # Each real recipient receives and decrypts the invite,
                    # then ingests the group message through the same relay.
                    for peer in (self.bob, self.carol):
                        ok, _ = peer.sync_global()
                        self.assertTrue(ok)
                        self.assertIn(group["id"], peer.state["global"]["groups"])

                    ok, result = self.alice.send_group_message(
                        group["id"], "group payload stays private"
                    )
                    self.assertTrue(ok, result)
                    for peer in (self.bob, self.carol):
                        ok, _ = peer.sync_global()
                        self.assertTrue(ok)
                        received = [
                            message for message in peer.state["global"]["messages"]
                            if message.get("message_type") == "group_message"
                        ]
                        self.assertEqual(len(received), 1)
                        self.assertEqual(received[0]["text"], "group payload stays private")
                        self.assertEqual(received[0]["group_id"], group["id"])

                    with relay.server.events_lock:
                        gifts = [
                            event for event in relay.server.events.values()
                            if event.get("kind") == friends.NIP59_GIFT_WRAP_KIND
                        ]
                    self.assertGreaterEqual(len(gifts), 4)
                    for gift in gifts:
                        serialized = json.dumps(gift, sort_keys=True)
                        recipients = [tag[1] for tag in gift.get("tags", []) if len(tag) >= 2 and tag[0] == "p"]
                        self.assertEqual(len(recipients), 1)
                        recipient = recipients[0]
                        if self.key(self.alice) != recipient:
                            self.assertNotIn(self.key(self.alice), serialized)
                        for member_key in (self.key(self.bob), self.key(self.carol)):
                            if member_key != recipient:
                                self.assertNotIn(member_key, serialized)
                        self.assertNotIn("group payload stays private", serialized)
                        self.assertNotIn(group["id"], serialized)

    def make_friends(self, left, right):
        lkey, rkey = self.key(left), self.key(right)
        left.state["global"]["friendships"][rkey] = {
            "status": "friends", "handle": "Friend", "avatar": "🦊"
        }
        right.state["global"]["friendships"][lkey] = {
            "status": "friends", "handle": "Friend", "avatar": "🦊"
        }
        left.save_state()
        right.save_state()

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
        self.assertEqual(self.alice.last_sent_message_id, self.alice.state["global"]["messages"][-1]["id"])
        self.assertEqual(len(published), 1, "direct send should not wait for a redundant self-copy")
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

    def test_nip17_reply_round_trip_has_standard_event_reference(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, relays: (published.append(event) or True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "first message")
            self.assertTrue(ok, message)
            first = next(item for item in self.alice.state["global"]["messages"] if item["text"] == "first message")
            ok, message = self.alice.send_dm(
                self.key(self.bob), "answer", reply_to={"id": first["id"], "text": "tampered preview"}
            )
        self.assertTrue(ok, message)
        gift = published[-1]
        rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], gift)
        self.assertIn(["e", first["id"]], rumor["tags"])
        opened = self.bob._global_dm_from_event(gift)
        self.assertEqual(opened["text"], "answer")
        self.assertEqual(opened["reply_to"], {"id": first["id"], "handle": "Friend", "text": "first message"})

    def test_reply_rejects_unknown_or_cross_conversation_parent(self):
        self.make_friends(self.alice, self.bob)
        with patch.object(self.alice, "_publish_event_to_relays", return_value=(True, {})) as publish:
            ok, message = self.alice.send_dm(
                self.key(self.bob), "answer", reply_to={"id": "a" * 64, "text": "not locally present"}
            )
        self.assertFalse(ok)
        self.assertIn("reply is no longer available", message)
        publish.assert_not_called()

    def test_reply_metadata_requires_matching_nip17_e_tag(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        reply_id = "b" * 64
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"],
            [self.key(self.bob)],
            "answer",
            app_envelope={"v": 3, "type": "direct", "text": "answer", "reply_to": {"id": reply_id, "text": "quoted"}},
        )
        gift = friends.wrap_nip17_rumor(self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor)
        self.assertIsNone(self.bob._global_dm_from_event(gift))

    def test_nip17_reaction_round_trip_updates_one_reaction_per_friend(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        sent_by_alice = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, relays: (sent_by_alice.append(event) or True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "React to this")
        self.assertTrue(ok, message)
        original = sent_by_alice[-1]
        self.assertTrue(self.bob._ingest_global_dm(original))
        target_id = next(item["id"] for item in self.alice.state["global"]["messages"] if item["text"] == "React to this")

        sent_by_bob = []
        with patch.object(
            self.bob, "_publish_event_to_relays",
            side_effect=lambda event, relays: (sent_by_bob.append(event) or True, {}),
        ):
            ok, message = self.bob.react_to_message(target_id, self.key(self.alice), "", "❤️")
        self.assertTrue(ok, message)
        reaction_event = sent_by_bob[-1]
        rumor = friends.unwrap_nip17_gift_wrap(self.alice.state["global_identity"]["secret_key"], reaction_event)
        self.assertEqual(rumor["kind"], friends.NIP17_REACTION_KIND)
        self.assertIn(["e", target_id], rumor["tags"])
        self.assertTrue(self.alice._ingest_global_dm(reaction_event))
        target = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(target["reactions"], [{"emoji": "❤️", "public_key": self.key(self.bob), "handle": "Friend"}])
        self.assertFalse(self.alice._ingest_global_dm(reaction_event))
        self.assertEqual(len(target["reactions"]), 1)

    def test_failed_reaction_keeps_private_retry_action_across_restart(self):
        self.make_friends(self.alice, self.bob)
        original_event = friends.build_event(
            self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND,
            [["p", self.key(self.bob)], ["t", friends.GLOBAL_DM_TAG]], "target",
        )
        self.alice.state["global"]["messages"].append({
            "id": original_event["id"], "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "reaction retry target", "incoming": False,
        })
        target = self.alice.state["global"]["messages"][-1]
        with patch.object(self.alice, "_publish_global_event", return_value=(False, {})):
            ok, message = self.alice.react_to_message(target["id"], self.key(self.bob), "", "❤️")
        self.assertFalse(ok)
        self.assertIn("retry remains available", message)
        status_message = self.alice.get_full_status()["global_messages"][0]
        self.assertTrue(status_message["retryable_actions"])
        self.assertNotIn("pending_actions", status_message)
        self.assertNotIn("transports", status_message)
        self.assertNotIn("ciphertext", json.dumps(status_message))
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertEqual(len(restored.state["global"]["messages"][-1]["pending_actions"]), 1)
        retried = []
        with patch.object(restored, "_publish_global_event", side_effect=lambda event: retried.append(event) or (True, {})):
            ok, message = restored.retry_message_action(target["id"])
        self.assertTrue(ok, message)
        self.assertEqual(restored.state["global"]["messages"][-1]["pending_actions"], [])
        self.assertEqual(len(retried), 1)
        self.assertEqual(retried[0]["kind"], friends.GLOBAL_DM_KIND)

    def test_failed_delete_retains_retry_payload_across_restart(self):
        self.make_friends(self.alice, self.bob)
        original_event = friends.build_event(
            self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND,
            [["p", self.key(self.bob)], ["t", friends.GLOBAL_DM_TAG]], "target",
        )
        target_id = original_event["id"]
        self.alice.state["global"]["messages"].append({
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "delete retry target", "incoming": False, "sendState": "Sent",
        })
        target = self.alice.state["global"]["messages"][-1]
        with patch.object(self.alice, "_publish_global_event", return_value=(False, {})):
            ok, message = self.alice.delete_message(target["id"])
        self.assertFalse(ok)
        self.assertIn("retry remains available", message)
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertEqual(restored.state["global"]["messages"][-1]["pending_actions"][0]["kind"], "delete")
        retried = []
        with patch.object(restored, "_publish_global_event", side_effect=lambda event: retried.append(event) or (True, {})):
            ok, message = restored.retry_message_action(target["id"])
        self.assertTrue(ok, message)
        self.assertEqual(restored.state["global"]["messages"][-1]["pending_actions"], [])
        self.assertEqual(len(retried), 1)

    def test_group_reaction_partial_ack_retries_only_unconfirmed_member(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.alice, self.carol)
        group_id = "reaction-retry"
        target_id = friends.build_event(self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND, [], "target")["id"]
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "members": {
                self.key(self.alice): {}, self.key(self.bob): {}, self.key(self.carol): {},
            },
        }
        target = {
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": "",
            "group_id": group_id, "text": "group target", "incoming": False,
        }
        self.alice.state["global"]["messages"].append(target)
        sent = []

        def ack_bob(event, _relays):
            sent.append(event)
            recipient = next(tag[1] for tag in event["tags"] if tag[0] == "p")
            return recipient == self.key(self.bob), {}

        with patch.object(self.alice, "_publish_event_to_relays", side_effect=ack_bob):
            ok, message = self.alice.react_to_message(target_id, "", group_id, "❤️")
        self.assertFalse(ok)
        self.assertIn("1 of 2", message)
        self.assertEqual(target["pending_actions"][0]["recipients"], [self.key(self.carol)])
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        restored.state["global"]["groups"][group_id] = self.alice.state["global"]["groups"][group_id]
        retried = []
        with patch.object(restored, "_publish_event_to_relays", side_effect=lambda event, _relays: retried.append(event) or (True, {})):
            ok, message = restored.retry_message_action(target_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(retried), 1)
        self.assertEqual([tag[1] for tag in retried[0]["tags"] if tag[0] == "p"], [self.key(self.carol)])
        retry_rumor = friends.unwrap_nip17_gift_wrap(self.carol.state["global_identity"]["secret_key"], retried[0])
        self.assertEqual(friends.app_envelope_from_rumor(retry_rumor)["emoji"], "❤️")

    def test_group_delete_partial_ack_keeps_only_failed_recipient(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.alice, self.carol)
        group_id = "delete-retry"
        target_id = friends.build_event(self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND, [], "target")["id"]
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "members": {
                self.key(self.alice): {}, self.key(self.bob): {}, self.key(self.carol): {},
            },
        }
        target = {
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": "",
            "group_id": group_id, "text": "group target", "incoming": False,
        }
        self.alice.state["global"]["messages"].append(target)
        sent = []

        def ack_bob(event, _relays):
            sent.append(event)
            recipient = next(tag[1] for tag in event["tags"] if tag[0] == "p")
            return recipient == self.key(self.bob), {}

        with patch.object(self.alice, "_publish_event_to_relays", side_effect=ack_bob):
            ok, message = self.alice.delete_message(target_id)
        self.assertFalse(ok)
        self.assertIn("1 of 2", message)
        self.assertTrue(target["deleted"])
        self.assertEqual(target["text"], "Message deleted")
        self.assertEqual(target["sendState"], "Deletion pending · retry")
        self.assertEqual(target["pending_actions"][0]["recipients"], [self.key(self.carol)])
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        restored.state["global"]["groups"][group_id] = self.alice.state["global"]["groups"][group_id]
        retried = []
        with patch.object(restored, "_publish_event_to_relays", side_effect=lambda event, _relays: retried.append(event) or (True, {})):
            ok, message = restored.retry_message_action(target_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(retried), 1)
        self.assertEqual([tag[1] for tag in retried[0]["tags"] if tag[0] == "p"], [self.key(self.carol)])

    def test_group_edit_partial_ack_retries_only_unconfirmed_member(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.alice, self.carol)
        group_id = "edit-retry"
        target_id = friends.build_event(self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND, [], "target")["id"]
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "name": "Edit crew", "members": {
                self.key(self.alice): {}, self.key(self.bob): {}, self.key(self.carol): {},
            },
        }
        self.alice.state["global"]["messages"].append({
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": "",
            "group_id": group_id, "group_name": "Edit crew", "text": "before",
            "incoming": False, "timestamp": friends.now_seconds(), "sendState": "Sent",
        })
        sent = []

        def ack_bob(event, _relays):
            sent.append(event)
            recipient = next(tag[1] for tag in event["tags"] if tag[0] == "p")
            return recipient == self.key(self.bob), {}

        with patch.object(self.alice, "_publish_event_to_relays", side_effect=ack_bob):
            ok, message = self.alice.edit_message(target_id, "after")
        self.assertFalse(ok)
        self.assertIn("1 of 2", message)
        target = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(target["text"], "after")
        self.assertEqual(target["pending_actions"][0]["recipients"], [self.key(self.carol)])
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        restored.state["global"]["groups"][group_id] = self.alice.state["global"]["groups"][group_id]
        retried = []
        with patch.object(restored, "_publish_event_to_relays", side_effect=lambda event, _relays: retried.append(event) or (True, {})):
            ok, message = restored.retry_message_action(target_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(retried), 1)
        retry_rumor = friends.unwrap_nip17_gift_wrap(self.carol.state["global_identity"]["secret_key"], retried[0])
        self.assertEqual(friends.app_envelope_from_rumor(retry_rumor)["text"], "after")

    def test_legacy_group_action_retries_each_failed_recipient(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        group_id = "legacy-actions"
        target_id = friends.build_event(self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND, [], "target")["id"]
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "members": {
                self.key(self.alice): {}, self.key(self.bob): {}, self.key(self.carol): {},
            },
        }
        target = {
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": "",
            "group_id": group_id, "text": "target", "incoming": False,
            "timestamp": friends.now_seconds(), "sendState": "Sent",
        }
        self.alice.state["global"]["messages"].append(target)

        def legacy_ack_one(event):
            recipient = next(tag[1] for tag in event["tags"] if tag[0] == "p")
            return recipient == self.key(self.bob), {}

        with patch.object(self.alice, "_publish_global_event", side_effect=legacy_ack_one):
            ok, message = self.alice.edit_message(target_id, "edited")
        self.assertFalse(ok)
        self.assertEqual(target["pending_actions"][0]["recipients"], [self.key(self.carol)])
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        restored.state["global"]["groups"][group_id] = self.alice.state["global"]["groups"][group_id]
        retried = []
        with patch.object(restored, "_publish_global_event", side_effect=lambda event: retried.append(event) or (True, {})):
            ok, message = restored.retry_message_action(target_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(retried), 1)
        self.assertEqual(next(tag[1] for tag in retried[0]["tags"] if tag[0] == "p"), self.key(self.carol))

    def test_partial_group_delete_keeps_retry_action_visible_in_status(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        group_id = "visible-delete-retry"
        target_id = friends.build_event(self.alice.state["global_identity"]["secret_key"], friends.GLOBAL_DM_KIND, [], "target")["id"]
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "members": {
                self.key(self.alice): {}, self.key(self.bob): {}, self.key(self.carol): {},
            },
        }
        target = {
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": "",
            "group_id": group_id, "text": "target", "incoming": False,
            "timestamp": friends.now_seconds(), "sendState": "Sent",
        }
        self.alice.state["global"]["messages"].append(target)
        with patch.object(self.alice, "_publish_global_event", side_effect=lambda event: (
            next(tag[1] for tag in event["tags"] if tag[0] == "p") == self.key(self.bob), {},
        )):
            ok, message = self.alice.delete_message(target_id)
        self.assertFalse(ok)
        self.assertTrue(target["deleted"])
        self.assertEqual(target["sendState"], "Deletion pending · retry")
        status = next(item for item in self.alice.get_full_status()["global_messages"] if item["id"] == target_id)
        self.assertTrue(status["retryable_actions"])

    def test_reaction_cannot_target_another_friend_conversation(self):
        self.make_friends(self.alice, self.bob)
        self.alice.state["global"]["messages"].append({
            "id": "c" * 64, "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "private", "incoming": False,
        })
        ok, message = self.alice.react_to_message("c" * 64, self.key(self.carol), "", "👍")
        self.assertFalse(ok)
        self.assertIn("no longer available", message)

    def test_nip17_delete_removes_message_content_for_both_people(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        sent = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: sent.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "remove this secret")
        self.assertTrue(ok, message)
        original_event = sent[-1]
        self.assertTrue(self.bob._ingest_global_dm(original_event))
        target = next(item for item in self.alice.state["global"]["messages"] if item["text"] == "remove this secret")
        target_id = target["id"]
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: sent.append(event) or (True, {}),
        ):
            ok, message = self.alice.delete_message(target_id)
        self.assertTrue(ok, message)
        delete_event = sent[-1]
        rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], delete_event)
        self.assertEqual(rumor["kind"], friends.NIP17_DELETE_KIND)
        self.assertIn(["e", target_id], rumor["tags"])
        self.assertTrue(self.bob._ingest_global_dm(delete_event))
        deleted = next(item for item in self.bob.state["global"]["messages"] if item["id"] == target_id)
        self.assertTrue(deleted["deleted"])
        self.assertEqual(deleted["text"], "Message deleted")
        self.assertEqual(deleted["attachments"], [])
        self.assertFalse(self.bob._ingest_global_dm(delete_event))

    def test_delete_for_me_is_local_persistent_and_never_published(self):
        message_id = "e" * 64
        self.alice.state["global"]["messages"].append({
            "id": message_id, "public_key": self.key(self.bob), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "keep this private", "incoming": True, "timestamp": 1,
        })
        self.alice.save_state()
        with patch.object(self.alice, "_publish_global_event", side_effect=AssertionError("local removal must not publish")), \
             patch.object(self.alice, "_publish_nip17", side_effect=AssertionError("local removal must not publish")):
            ok, message = self.alice.delete_message_for_me(message_id)
        self.assertTrue(ok, message)
        status = self.alice.get_full_status()
        self.assertNotIn(message_id, [item["id"] for item in status["global_messages"]])
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertIn(message_id, restored.state["global"]["locally_hidden_message_ids"])
        self.assertEqual(restored.state["global"]["messages"], [])
        import sqlite3
        db = sqlite3.connect(restored.message_journal_file)
        try:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM messages").fetchone()[0], 0)
        finally:
            db.close()

    def test_nip17_text_edit_is_encrypted_author_checked_and_updates_original(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "before edit")
        self.assertTrue(ok, message)
        original_event = sent[-1]
        self.assertTrue(self.bob._ingest_global_dm(original_event))
        target_id = self.alice.state["global"]["messages"][-1]["id"]
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.edit_message(target_id, "after edit")
        self.assertTrue(ok, message)
        edit_event = sent[-1]
        rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], edit_event)
        self.assertEqual(rumor["kind"], friends.NIP17_MESSAGE_KIND)
        self.assertNotIn("after edit", json.dumps(edit_event))
        self.assertTrue(self.bob._ingest_global_dm(edit_event))
        self.bob.save_state()
        updated = next(item for item in self.bob.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(updated["text"], "after edit")
        self.assertTrue(updated["edited"])
        restored_bob = friends.FriendsEngine(state_dir=self.paths[1])
        restored = next(item for item in restored_bob.state["global"]["messages"] if item["id"] == target_id)
        self.assertTrue(restored["edited"])
        self.assertGreater(restored["edited_at"], 0)
        self.assertFalse(self.bob._ingest_global_dm(edit_event))

    def test_legacy_edit_is_encrypted_and_edit_before_original_is_applied(self):
        self.make_friends(self.alice, self.bob)
        sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "before edit")
        self.assertTrue(ok, message)
        original_event = sent[-1]
        target_id = self.alice.state["global"]["messages"][-1]["id"]
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.edit_message(target_id, "after edit")
        self.assertTrue(ok, message)
        edit_event = sent[-1]
        self.assertEqual(edit_event["kind"], friends.GLOBAL_DM_KIND)
        self.assertNotIn("after edit", json.dumps(edit_event))
        self.assertTrue(self.bob._ingest_global_dm(edit_event))
        self.assertIn(target_id, self.bob.state["global"]["pending_private_edits"])
        self.bob.save_state()
        restarted_bob = friends.FriendsEngine(state_dir=self.paths[1])
        self.assertIn(target_id, restarted_bob.state["global"]["pending_private_edits"])
        self.assertTrue(restarted_bob._ingest_global_dm(original_event))
        updated = next(item for item in restarted_bob.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(updated["text"], "after edit")
        self.assertTrue(updated["edited"])

    def test_edit_rejects_other_authors_attachments_and_expired_window(self):
        self.make_friends(self.alice, self.bob)
        incoming_id = "f" * 64
        self.alice.state["global"]["messages"].append({
            "id": incoming_id, "public_key": self.key(self.bob), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "friend text", "incoming": True, "timestamp": friends.now_seconds(),
        })
        with patch.object(self.alice, "_publish_event_to_relays") as publish:
            ok, message = self.alice.edit_message(incoming_id, "tampered")
        self.assertFalse(ok)
        publish.assert_not_called()
        attachment_id = "a" * 64
        self.alice.state["global"]["messages"].append({
            "id": attachment_id, "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "file", "attachments": [{"name": "x"}],
            "incoming": False, "sendState": "Sent", "timestamp": friends.now_seconds(),
        })
        ok, message = self.alice.edit_message(attachment_id, "tampered")
        self.assertFalse(ok)
        self.assertIn("text-only", message)
        expired_id = "b" * 64
        self.alice.state["global"]["messages"].append({
            "id": expired_id, "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "old", "incoming": False, "sendState": "Sent",
            "timestamp": friends.now_seconds() - 901,
        })
        ok, message = self.alice.edit_message(expired_id, "too late")
        self.assertFalse(ok)
        self.assertIn("15 minutes", message)

    def test_incoming_edit_from_another_author_cannot_change_local_message(self):
        self.make_friends(self.alice, self.bob)
        target_id = "d" * 64
        self.alice.state["global"]["messages"].append({
            "id": target_id, "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "authored by Alice", "incoming": False,
            "sendState": "Sent", "timestamp": friends.now_seconds(),
        })
        forged_edit = self.bob._legacy_private_event(
            self.key(self.alice),
            {"v": 3, "type": "edit", "target_id": target_id, "group_id": "", "text": "forged"},
            [["e", target_id]],
            "Omarchy Friends private message edit",
        )
        self.assertTrue(self.alice._ingest_global_dm(forged_edit))
        target = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(target["text"], "authored by Alice")
        self.assertNotIn("edited", target)

    def test_nip17_group_text_edit_only_updates_matching_group_message(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        group_id = "group-edit"
        members = {self.key(self.alice): {}, self.key(self.bob): {}}
        for engine in (self.alice, self.bob):
            engine.state["global"]["groups"][group_id] = {"id": group_id, "name": "Shared", "members": members}
        message_id = "c" * 64
        for engine, incoming in ((self.alice, False), (self.bob, True)):
            engine.state["global"]["messages"].append({
                "id": message_id, "public_key": self.key(self.alice), "handle": "Alice",
                "group_id": group_id, "group_name": "Shared", "text": "group before",
                "incoming": incoming, "sendState": "Sent", "timestamp": friends.now_seconds(),
            })
        sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.edit_message(message_id, "group after")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        updated = next(item for item in self.bob.state["global"]["messages"] if item["id"] == message_id)
        self.assertEqual(updated["text"], "group after")
        self.assertTrue(updated["edited"])

    def test_read_receipts_are_off_by_default_and_do_not_publish(self):
        self.make_friends(self.alice, self.bob)
        self.alice.state["global"]["messages"].append({
            "id": "1" * 64, "public_key": self.key(self.alice), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "private", "incoming": False, "sendState": "Sent",
            "timestamp": friends.now_seconds(),
        })
        self.bob.state["global"]["messages"].append({
            "id": "1" * 64, "public_key": self.key(self.alice), "conversation_key": self.key(self.alice),
            "group_id": "", "text": "private", "incoming": True, "timestamp": friends.now_seconds(),
            "received_at_ms": friends.now_seconds() * 1000,
        })
        with patch.object(self.bob, "_publish_event_to_relays") as publish:
            ok, message = self.bob.mark_conversation_read("friend", self.key(self.alice))
        self.assertTrue(ok, message)
        publish.assert_not_called()
        self.assertFalse(self.bob.state["global"]["messages"][0].get("read_receipt_eligible", False))

    def test_nip17_read_receipt_updates_only_existing_private_message_and_deduplicates(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        alice_sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: alice_sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "read me")
        self.assertTrue(ok, message)
        original_event = alice_sent[-1]
        self.assertTrue(self.bob._ingest_global_dm(original_event))
        target_id = self.alice.state["global"]["messages"][-1]["id"]
        self.bob.state["profile"]["privacy"]["share_read_receipts"] = True
        receipt_events = []
        with patch.object(self.bob, "_publish_event_to_relays", side_effect=lambda event, _relays: receipt_events.append(event) or (True, {})):
            ok, message = self.bob.mark_conversation_read("friend", self.key(self.alice))
            self.assertTrue(ok, message)
            self.bob.mark_conversation_read("friend", self.key(self.alice))
        self.assertEqual(len(receipt_events), 1)
        self.assertNotIn(target_id, json.dumps(receipt_events[0]))
        self.assertTrue(self.alice._ingest_global_dm(receipt_events[0]))
        updated = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
        self.assertIn(self.key(self.bob), updated["read_by"])
        self.assertEqual(len(self.alice.state["global"]["messages"]), 1)

    def test_legacy_read_receipt_uses_encrypted_compatibility_transport(self):
        self.make_friends(self.alice, self.bob)
        alice_sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: alice_sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "legacy read")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(alice_sent[-1]))
        self.bob.state["profile"]["privacy"]["share_read_receipts"] = True
        receipt_events = []
        with patch.object(self.bob, "_publish_event_to_relays", side_effect=lambda event, _relays: receipt_events.append(event) or (True, {})):
            ok, message = self.bob.mark_conversation_read("friend", self.key(self.alice))
        self.assertTrue(ok, message)
        self.assertEqual(receipt_events[-1]["kind"], friends.GLOBAL_DM_KIND)
        self.assertNotIn("read_receipt", json.dumps(receipt_events[-1]))
        self.assertTrue(self.alice._ingest_global_dm(receipt_events[-1]))
        self.assertIn(self.key(self.bob), self.alice.state["global"]["messages"][-1]["read_by"])

    def test_unconfirmed_read_receipt_retries_on_the_next_chat_open(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "retry read receipt")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        self.bob.state["profile"]["privacy"]["share_read_receipts"] = True
        with patch.object(self.bob, "_publish_event_to_relays", return_value=(False, {})) as publish:
            self.bob.mark_conversation_read("friend", self.key(self.alice))
        self.assertEqual(publish.call_count, 1)
        self.assertTrue(self.bob.state["global"]["messages"][0]["read_receipt_eligible"])
        confirmed = []
        with patch.object(self.bob, "_publish_event_to_relays", side_effect=lambda event, _relays: confirmed.append(event) or (True, {})):
            self.bob.mark_conversation_read("friend", self.key(self.alice))
        self.assertEqual(len(confirmed), 1)
        self.assertFalse(self.bob.state["global"]["messages"][0]["read_receipt_eligible"])

    def test_unconfirmed_read_receipt_retries_automatically_after_backoff(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        sent = []
        with patch.object(self.alice, "_publish_event_to_relays", side_effect=lambda event, _relays: sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "automatic receipt retry")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        self.bob.state["profile"]["privacy"]["share_read_receipts"] = True
        with patch.object(self.bob, "_publish_event_to_relays", return_value=(False, {})):
            self.bob.mark_conversation_read("friend", self.key(self.alice))
        pending = self.bob.state["global"]["messages"][0]
        self.assertTrue(pending["read_receipt_eligible"])
        self.assertEqual(pending["read_receipt_retry_attempts"], 1)
        pending["read_receipt_retry_at"] = friends.now_seconds() - 1
        confirmed = []
        with patch.object(self.bob, "_publish_event_to_relays", side_effect=lambda event, _relays: confirmed.append(event) or (True, {})):
            attempted, published = self.bob.retry_pending_read_receipts()
        self.assertEqual((attempted, published), (1, 1))
        self.assertEqual(len(confirmed), 1)
        self.assertFalse(self.bob.state["global"]["messages"][0]["read_receipt_eligible"])

    def test_read_receipt_retry_worker_does_nothing_when_user_opts_out(self):
        self.make_friends(self.alice, self.bob)
        self.bob.state["global"]["messages"].append({
            "id": "4" * 64, "public_key": self.key(self.alice), "group_id": "",
            "text": "private receipt", "incoming": True, "read_receipt_eligible": True,
            "read_receipt_retry_attempts": 0, "read_receipt_retry_at": friends.now_seconds() - 1,
        })
        with patch.object(self.bob, "_publish_event_to_relays") as publish:
            self.assertEqual(self.bob.retry_pending_read_receipts(), (0, 0))
        publish.assert_not_called()

    def test_turning_read_receipts_off_cancels_unsent_receipts(self):
        self.bob.state["profile"]["privacy"]["share_read_receipts"] = True
        self.bob.state["global"]["messages"].append({
            "id": "5" * 64, "public_key": self.key(self.alice), "group_id": "",
            "text": "do not disclose after opt-out", "incoming": True,
            "read_receipt_eligible": True, "read_receipt_retry_attempts": 2,
            "read_receipt_retry_at": friends.now_seconds() + 60,
        })
        self.assertFalse(self.bob.toggle_privacy("share_read_receipts"))
        message = self.bob.state["global"]["messages"][0]
        self.assertFalse(message["read_receipt_eligible"])
        self.assertEqual(message["read_receipt_retry_at"], 0)

    def test_group_read_receipts_apply_to_each_authors_own_group_message(self):
        for left, right in ((self.alice, self.bob), (self.bob, self.carol), (self.alice, self.carol)):
            self.make_friends(left, right)
        self.advertise_modern(self.bob, self.alice)
        self.advertise_modern(self.bob, self.carol)
        group_id = "group-read"
        members = {self.key(engine): {} for engine in (self.alice, self.bob, self.carol)}
        for engine in (self.alice, self.bob, self.carol):
            engine.state["global"]["groups"][group_id] = {"id": group_id, "name": "Shared", "members": members}
        alice_message_id, carol_message_id = "2" * 64, "3" * 64
        self.bob.state["profile"]["privacy"]["share_read_receipts"] = True
        self.alice.state["global"]["messages"].append({
            "id": alice_message_id, "public_key": self.key(self.alice), "group_id": group_id,
            "text": "group note", "incoming": False, "sendState": "Sent", "timestamp": friends.now_seconds(),
        })
        self.carol.state["global"]["messages"].append({
            "id": carol_message_id, "public_key": self.key(self.carol), "group_id": group_id,
            "text": "group note", "incoming": False, "sendState": "Sent", "timestamp": friends.now_seconds(),
        })
        for message_id, sender in ((alice_message_id, self.alice), (carol_message_id, self.carol)):
            self.bob.state["global"]["messages"].append({
                "id": message_id, "public_key": self.key(sender), "group_id": group_id,
                "text": "group note", "incoming": True, "timestamp": friends.now_seconds(),
                "received_at_ms": friends.now_seconds() * 1000,
            })
        receipt_events = []
        with patch.object(self.bob, "_publish_event_to_relays", side_effect=lambda event, _relays: receipt_events.append(event) or (True, {})):
            ok, message = self.bob.mark_conversation_read("group", group_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(receipt_events), 2)
        self.assertTrue(self.alice._ingest_global_dm(receipt_events[0]))
        self.assertTrue(self.carol._ingest_global_dm(receipt_events[1]))
        alice_message = next(item for item in self.alice.state["global"]["messages"] if item["id"] == alice_message_id)
        carol_message = next(item for item in self.carol.state["global"]["messages"] if item["id"] == carol_message_id)
        self.assertIn(self.key(self.bob), alice_message["read_by"])
        self.assertIn(self.key(self.bob), carol_message["read_by"])

    def test_delete_arriving_before_original_is_applied_when_message_arrives(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        sent = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: sent.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "arrives after deletion")
        self.assertTrue(ok, message)
        original_event = sent[-1]
        target_id = next(item["id"] for item in self.alice.state["global"]["messages"] if item["text"] == "arrives after deletion")
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: sent.append(event) or (True, {}),
        ):
            ok, message = self.alice.delete_message(target_id)
        self.assertTrue(ok, message)
        deletion_event = sent[-1]
        self.assertTrue(self.bob._ingest_global_dm(deletion_event))
        self.assertIn(target_id, self.bob.state["global"].setdefault("pending_private_deletions", {}))
        self.assertTrue(self.bob._ingest_global_dm(original_event))
        message = next(item for item in self.bob.state["global"]["messages"] if item["id"] == target_id)
        self.assertTrue(message["deleted"])
        self.assertEqual(message["text"], "Message deleted")

    def test_cannot_delete_another_persons_message(self):
        self.make_friends(self.alice, self.bob)
        self.alice.state["global"]["messages"].append({
            "id": "d" * 64, "public_key": self.key(self.bob), "conversation_key": self.key(self.bob),
            "group_id": "", "text": "received", "incoming": True,
        })
        with patch.object(self.alice, "_publish_event_to_relays") as publish:
            ok, message = self.alice.delete_message("d" * 64)
        self.assertFalse(ok)
        self.assertIn("Only your own", message)
        publish.assert_not_called()

    def test_delete_is_routed_through_legacy_private_transport_when_needed(self):
        self.make_friends(self.alice, self.bob)
        sent = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: sent.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "legacy message")
            self.assertTrue(ok, message)
            target = self.alice.state["global"]["messages"][-1]
            ok, message = self.alice.delete_message(target["id"])
        self.assertTrue(ok, message)
        self.assertEqual(sent[-1]["kind"], friends.GLOBAL_DM_KIND)
        opened = self.bob._global_dm_from_event(sent[-1])
        self.assertEqual(opened["message_type"], "delete")
        self.assertEqual(opened["delete_target_id"], target["id"])
        self.bob.state["global"]["messages"].append({
            "id": target["id"], "public_key": self.key(self.alice), "conversation_key": self.key(self.alice),
            "group_id": "", "text": "legacy message", "incoming": True,
        })
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        self.assertTrue(self.bob.state["global"]["messages"][-1]["deleted"])

    def test_group_deletion_is_encrypted_and_scoped_to_group(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        group_id = "e" * 40
        group = {
            "id": group_id, "name": "Private room",
            "members": {self.key(self.alice): {}, self.key(self.bob): {}},
        }
        self.alice.state["global"]["groups"][group_id] = json.loads(json.dumps(group))
        self.bob.state["global"]["groups"][group_id] = json.loads(json.dumps(group))
        message_id = "f" * 64
        self.alice.state["global"]["messages"].append({
            "id": message_id, "public_key": self.key(self.alice), "group_id": group_id,
            "text": "room message", "incoming": False,
        })
        self.bob.state["global"]["messages"].append({
            "id": message_id, "public_key": self.key(self.alice), "group_id": group_id,
            "text": "room message", "incoming": True,
        })
        sent = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: sent.append(event) or (True, {}),
        ):
            ok, message = self.alice.delete_message(message_id)
        self.assertTrue(ok, message)
        deletion = self.bob._global_dm_from_event(sent[-1])
        self.assertEqual(deletion["group_id"], group_id)
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        deleted = next(item for item in self.bob.state["global"]["messages"] if item["id"] == message_id)
        self.assertTrue(deleted["deleted"])

    def test_small_file_attachment_is_encrypted_and_round_trips(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        payload = b"friends-private-attachment-payload"
        path = Path(self.paths[0]) / "notes.txt"
        path.write_bytes(payload)
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "", "", str(path))
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 1)
        self.assertNotIn(payload.decode(), json.dumps(published[0]))
        opened = self.bob._global_dm_from_event(published[0])
        self.assertIsNotNone(opened)
        self.assertEqual(opened["attachments"][0]["name"], "notes.txt")
        self.assertEqual(base64.b64decode(opened["attachments"][0]["data"]), payload)
        normalized = self.bob._normalize_global_message(opened)
        self.assertEqual(normalized["attachments"][0]["sha256"], opened["attachments"][0]["sha256"])

    def test_private_attachments_reject_oversize_and_corrupt_payloads(self):
        path = Path(self.paths[0]) / "too-large.bin"
        path.write_bytes(b"x" * (friends.MAX_PRIVATE_ATTACHMENT_BYTES + 1))
        with self.assertRaisesRegex(ValueError, "16 KiB"):
            friends.read_private_attachment(path)
        self.assertEqual(friends.normalize_private_attachments([{"name": "bad", "data": "eA==", "sha256": "0" * 64}]), [])

    def test_large_attachment_is_encrypted_before_blossom_upload_and_stays_in_private_envelope(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.alice.set_blossom_server("https://files.example.test")
        payload = os.urandom(96 * 1024)
        path = Path(self.paths[0]) / "large.bin"
        path.write_bytes(payload)
        uploaded = {}

        def fake_upload(server, cipher_path, size, checksum):
            encrypted = Path(cipher_path).read_bytes()
            self.assertEqual(len(encrypted), size)
            self.assertEqual(hashlib.sha256(encrypted).hexdigest(), checksum)
            self.assertNotEqual(encrypted, payload)
            uploaded["ciphertext"] = encrypted
            return "https://cdn.example.test/blob/large"

        published = []
        with patch.object(self.alice, "_upload_ciphertext", side_effect=fake_upload), patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "", "", str(path))
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 1)
        event_json = json.dumps(published[0])
        self.assertNotIn("cdn.example.test", event_json)
        rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[0])
        self.assertEqual(rumor["kind"], friends.NIP17_FILE_KIND)
        file_tags = {tag[0]: tag[1] for tag in rumor["tags"] if len(tag) == 2}
        self.assertEqual(rumor["content"], "https://cdn.example.test/blob/large")
        self.assertEqual(file_tags["file-type"], "application/octet-stream")
        self.assertEqual(file_tags["encryption-algorithm"], "aes-gcm")
        self.assertRegex(file_tags["decryption-key"], r"^[A-Za-z0-9_-]{43}$")
        self.assertEqual(file_tags["x"], hashlib.sha256(uploaded["ciphertext"]).hexdigest())
        self.assertEqual(int(file_tags["size"]), len(uploaded["ciphertext"]))
        received = self.bob._global_dm_from_event(published[0])
        self.assertIsNotNone(received)
        attachment = received["attachments"][0]
        self.assertEqual(attachment["transport"], "blossom")
        self.assertEqual(file_tags["decryption-key"], attachment["key"])
        self.assertEqual(attachment["size"], len(payload))
        self.assertEqual(attachment["plain_sha256"], hashlib.sha256(payload).hexdigest())
        self.assertEqual(attachment["url"], "https://cdn.example.test/blob/large")

    def test_large_attachment_encryption_rejects_symlink_source_before_upload(self):
        self.alice.set_blossom_server("https://files.example.test")
        source = Path(self.paths[0]) / "large-source.bin"
        source.write_bytes(os.urandom(friends.MAX_PRIVATE_ATTACHMENT_BYTES + 1))
        link = Path(self.paths[0]) / "large-link.bin"
        link.symlink_to(source)

        with patch.object(self.alice, "_upload_ciphertext") as upload:
            with self.assertRaisesRegex(ValueError, "Could not prepare the encrypted attachment"):
                self.alice._upload_private_attachment(
                    link, "large-link.bin", "application/octet-stream"
                )

        upload.assert_not_called()
        self.assertEqual(list(self.alice.state_dir.glob(".attachment-*.enc")), [])

    def test_blossom_upload_rejects_private_or_mixed_dns_answers_before_connecting(self):
        self.make_friends(self.alice, self.bob)
        path = Path(self.paths[0]) / "large-upload.bin"
        path.write_bytes(b"x" * (friends.MAX_PRIVATE_ATTACHMENT_BYTES + 1))
        self.alice.set_blossom_server("https://files.example.test")
        private = (socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, "", ("127.0.0.1", 443))
        public = (socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, "", ("8.8.8.8", 443))
        translated_private = (
            socket.AF_INET6, socket.SOCK_STREAM, socket.IPPROTO_TCP, "",
            ("64:ff9b::7f00:1", 443, 0, 0),
        )
        for answers in ([private], [public, private], [translated_private], []):
            with self.subTest(answers=answers), patch.object(friends.socket, "getaddrinfo", return_value=answers), patch.object(
                friends, "PinnedPublicHTTPSConnection"
            ) as connection:
                with self.assertRaisesRegex(ValueError, "private or reserved"):
                    self.alice._upload_ciphertext("https://files.example.test", path, path.stat().st_size, "0" * 64)
                connection.assert_not_called()

    def test_blossom_upload_dns_resolution_failure_does_not_connect(self):
        self.make_friends(self.alice, self.bob)
        path = Path(self.paths[0]) / "large-upload.bin"
        path.write_bytes(b"x" * (friends.MAX_PRIVATE_ATTACHMENT_BYTES + 1))
        with patch.object(friends.socket, "getaddrinfo", side_effect=OSError("DNS unavailable")), patch.object(
            friends, "PinnedPublicHTTPSConnection"
        ) as connection:
            with self.assertRaisesRegex(ValueError, "Could not resolve"):
                self.alice._upload_ciphertext("https://files.example.test", path, path.stat().st_size, "0" * 64)
            connection.assert_not_called()

    def test_public_upload_address_filter_rejects_transition_ranges(self):
        self.assertTrue(friends._public_unicast_address("8.8.8.8"))
        self.assertTrue(friends._public_unicast_address("2606:4700:4700::1111"))
        for address in (
            "127.0.0.1", "10.1.2.3", "169.254.1.1", "::1", "::ffff:8.8.8.8",
            "2002:7f00:1::1", "64:ff9b::808:808", "64:ff9b::7f00:1", "ff02::1",
        ):
            with self.subTest(address=address):
                self.assertFalse(friends._public_unicast_address(address))

    def test_pinned_https_connection_uses_validated_ip_and_original_tls_hostname(self):
        wrapped = SimpleNamespace(close=lambda: None)
        raw_socket = object()
        with patch.object(friends.socket, "create_connection", return_value=raw_socket) as create_connection, patch.object(
            friends.ssl.SSLContext, "wrap_socket", return_value=wrapped
        ) as wrap_socket:
            connection = friends.PinnedPublicHTTPSConnection(
                "files.example.test", 443, "8.8.8.8", timeout=17,
                context=friends.ssl.create_default_context(),
            )
            connection.connect()
        create_connection.assert_called_once_with(("8.8.8.8", 443), 17, None)
        wrap_socket.assert_called_once_with(raw_socket, server_hostname="files.example.test")
        self.assertIs(connection.sock, wrapped)
        connection.sock = None

    def test_large_file_uses_kind14_when_peer_has_not_advertised_kind15(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        caps = self.alice.state["global"]["peers"][self.key(self.bob)]["capabilities"]
        caps.remove("nip17-file-kind15-v1")
        self.alice.set_blossom_server("https://files.example.test")
        path = Path(self.paths[0]) / "compatible-large.bin"
        path.write_bytes(os.urandom(96 * 1024))
        published = []
        with patch.object(self.alice, "_upload_ciphertext", return_value="https://cdn.example.test/blob/file"), patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "", "", str(path))
        self.assertTrue(ok, message)
        rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[0])
        self.assertEqual(rumor["kind"], friends.NIP17_MESSAGE_KIND)
        self.assertIsNotNone(self.bob._global_dm_from_event(published[0]))

    def test_nip17_file_metadata_must_match_encrypted_attachment_envelope(self):
        self.make_friends(self.alice, self.bob)
        metadata = {
            "url": "https://cdn.example.test/file",
            "content_type": "application/octet-stream",
            "key": base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("="),
            "nonce": base64.urlsafe_b64encode(os.urandom(12)).decode().rstrip("="),
            "sha256": "a" * 64,
            "cipher_size": 20,
        }
        envelope = {
            "v": 3, "type": "direct", "text": "Shared file",
            "attachments": [{**metadata, "url": "https://cdn.example.test/other", "transport": "blossom", "size": 4, "plain_sha256": "b" * 64}],
        }
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], [self.key(self.bob)], metadata["url"],
            kind=friends.NIP17_FILE_KIND, app_envelope=envelope, file_metadata=metadata,
        )
        event = friends.wrap_nip17_rumor(self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor)
        self.assertIsNone(self.bob._global_dm_from_event(event))

    def test_standard_nip17_file_without_friends_envelope_is_received_as_direct_attachment(self):
        self.make_friends(self.alice, self.bob)
        metadata = {
            "url": "https://cdn.example.test/files/report.pdf",
            "content_type": "application/pdf",
            "key": base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("="),
            "nonce": base64.urlsafe_b64encode(os.urandom(12)).decode().rstrip("="),
            "sha256": "a" * 64,
            "plain_sha256": "b" * 64,
            "cipher_size": 1024,
        }
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], [self.key(self.bob)], metadata["url"],
            kind=friends.NIP17_FILE_KIND, file_metadata=metadata,
        )
        event = friends.wrap_nip17_rumor(self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor)
        received = self.bob._global_dm_from_event(event)
        self.assertIsNotNone(received)
        self.assertEqual(received["text"], "Shared report.pdf")
        attachment = received["attachments"][0]
        self.assertEqual(attachment["transport"], "blossom")
        self.assertTrue(attachment["standard_nip17"])
        self.assertEqual(attachment["size"], 1008)
        self.assertEqual(attachment["plain_sha256"], "b" * 64)

    def test_standard_nip17_file_rejects_multiple_recipients(self):
        self.make_friends(self.alice, self.bob)
        metadata = {
            "url": "https://cdn.example.test/file", "content_type": "application/octet-stream",
            "key": base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("="),
            "nonce": base64.urlsafe_b64encode(os.urandom(12)).decode().rstrip("="),
            "sha256": "a" * 64, "cipher_size": 64,
        }
        third_party = friends.generate_keypair()["public_key"]
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], [self.key(self.bob), third_party], metadata["url"],
            kind=friends.NIP17_FILE_KIND, file_metadata=metadata,
        )
        event = friends.wrap_nip17_rumor(self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor)
        self.assertIsNone(self.bob._global_dm_from_event(event))

    def test_encrypted_state_and_append_only_journal_keep_messages_past_previous_cap(self):
        peer_key = self.key(self.bob)
        self.alice.state["global"]["messages"] = [
            {"id": f"{index:064x}", "public_key": peer_key, "handle": "Friend", "text": f"private-{index}",
             "timestamp": index + 1, "incoming": True}
            for index in range(2005)
        ]
        self.alice.save_state()
        stored = self.alice.state_file.read_bytes()
        self.assertTrue(stored.startswith(friends.STATE_FILE_MAGIC))
        self.assertNotIn(b"private-2004", stored)
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertEqual(len(restored.state["global"]["messages"]), 2005)
        self.assertEqual(restored.state["global"]["messages"][-1]["text"], "private-2004")
        self.assertEqual(os.stat(restored.state_key_file).st_mode & 0o777, 0o600)
        self.assertEqual(os.stat(restored.message_journal_file).st_mode & 0o777, 0o600)

    def test_state_key_migrates_to_secret_service_and_survives_restart(self):
        engine = self.alice
        local_key = engine.state_key_file.read_bytes()
        stored = {}
        engine.key_store = "secret-service"
        engine._secret_service_store_key = lambda key: stored.setdefault("key", key) == key
        engine._secret_service_lookup_key = lambda: stored.get("key")

        self.assertEqual(engine._get_state_key(), local_key)
        self.assertEqual(engine.state_key_file.read_bytes(), friends.STATE_KEY_SECRET_SERVICE_MARKER)
        self.assertNotIn(local_key, engine.state_key_file.read_bytes())

        with patch.object(friends.FriendsEngine, "_secret_service_lookup_key", return_value=local_key):
            restored = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertEqual(restored.state["global_identity"], engine.state["global_identity"])

    def test_secret_service_key_loss_fails_closed_without_replacing_key(self):
        engine = self.alice
        engine.state_key_file.write_bytes(friends.STATE_KEY_SECRET_SERVICE_MARKER)
        engine._secret_service_lookup_key = lambda: None
        with self.assertRaisesRegex(RuntimeError, "Secret Service"):
            engine._get_state_key(create=True)
        self.assertEqual(engine.state_key_file.read_bytes(), friends.STATE_KEY_SECRET_SERVICE_MARKER)

    def test_plaintext_legacy_state_is_encrypted_even_when_schema_is_already_current(self):
        legacy = json.loads(json.dumps(self.alice.state))
        legacy["global"]["messages"] = [{
            "id": "legacy-plaintext", "public_key": self.key(self.bob), "handle": "Friend",
            "text": "migrate this secret", "media": [], "attachments": [],
            "timestamp": 1, "incoming": True,
        }]
        self.alice.state_file.write_text(json.dumps(legacy), encoding="utf-8")
        migrated = friends.FriendsEngine(state_dir=self.paths[0])
        stored = migrated.state_file.read_bytes()
        self.assertTrue(stored.startswith(friends.STATE_FILE_MAGIC))
        self.assertNotIn(b"migrate this secret", stored)
        self.assertEqual(migrated.state["global"]["messages"][0]["text"], "migrate this secret")

    def test_blossom_download_authenticates_before_saving_to_downloads(self):
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM

        plain = b"private file contents"
        key, nonce = os.urandom(32), os.urandom(12)
        ciphertext = AESGCM(key).encrypt(nonce, plain, None)
        descriptor = {
            "transport": "blossom", "name": "notes.txt", "content_type": "text/plain",
            "size": len(plain), "cipher_size": len(ciphertext),
            "sha256": hashlib.sha256(ciphertext).hexdigest(),
            "plain_sha256": hashlib.sha256(plain).hexdigest(),
            "url": "https://cdn.example.test/blob/notes", "is_archive": False,
            "key": base64.urlsafe_b64encode(key).decode().rstrip("="),
            "nonce": base64.urlsafe_b64encode(nonce).decode().rstrip("="),
        }

        class FakeResponse:
            status = 200
            def __init__(self): self.body = BytesIO(ciphertext)
            def getheader(self, name): return str(len(ciphertext)) if name == "Content-Length" else None
            def read(self, size=-1): return self.body.read(size)

        class FakeConnection:
            def __init__(self, *_args, **_kwargs): pass
            def request(self, *_args, **_kwargs): pass
            def getresponse(self): return FakeResponse()
            def close(self): pass

        self.alice.state["global"]["messages"] = [{
            "id": "download-test", "public_key": self.key(self.bob), "handle": "Friend",
            "text": "Shared notes.txt", "attachments": [descriptor], "timestamp": 1, "incoming": True,
        }]
        home = Path(self.paths[0]) / "home"
        with patch.object(friends, "PinnedPublicHTTPSConnection", FakeConnection), patch.object(
            friends.socket, "getaddrinfo", return_value=[(2, 1, 6, "", ("8.8.8.8", 443))]
        ), patch.object(Path, "home", return_value=home):
            ok, result = self.alice.save_attachment("download-test")
        self.assertTrue(ok, result)
        saved = Path(result)
        self.assertEqual(saved.read_bytes(), plain)
        self.assertEqual(os.stat(saved).st_mode & 0o777, 0o600)

    def _save_blossom_response_for_test(self, descriptor, response_bytes):
        class FakeResponse:
            status = 200

            def __init__(self):
                self.body = BytesIO(response_bytes)

            def getheader(self, name):
                return None

            def read(self, size=-1):
                return self.body.read(size)

        class FakeConnection:
            def __init__(self, *_args, **_kwargs):
                pass

            def request(self, *_args, **_kwargs):
                pass

            def getresponse(self):
                return FakeResponse()

            def close(self):
                pass

        self.alice.state["global"]["messages"] = [{
            "id": "download-negative-test", "public_key": self.key(self.bob),
            "handle": "Friend", "text": "Shared file", "attachments": [descriptor],
            "timestamp": 1, "incoming": True,
        }]
        home = Path(self.paths[0]) / "negative-download-home"
        with patch.object(friends, "PinnedPublicHTTPSConnection", FakeConnection), patch.object(
            friends.socket, "getaddrinfo",
            return_value=[(2, 1, 6, "", ("8.8.8.8", 443))],
        ), patch.object(Path, "home", return_value=home):
            result = self.alice.save_attachment("download-negative-test")
        return result, home

    def test_blossom_download_rejects_tampered_ciphertext_and_cleans_temporary_files(self):
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM

        plain = b"must authenticate before saving"
        key, nonce = os.urandom(32), os.urandom(12)
        ciphertext = bytearray(AESGCM(key).encrypt(nonce, plain, None))
        ciphertext[-1] ^= 1
        ciphertext = bytes(ciphertext)
        descriptor = {
            "transport": "blossom", "name": "notes.txt", "content_type": "text/plain",
            "size": len(plain), "cipher_size": len(ciphertext),
            "sha256": hashlib.sha256(ciphertext).hexdigest(),
            "plain_sha256": hashlib.sha256(plain).hexdigest(),
            "url": "https://cdn.example.test/blob/notes", "is_archive": False,
            "key": base64.urlsafe_b64encode(key).decode().rstrip("="),
            "nonce": base64.urlsafe_b64encode(nonce).decode().rstrip("="),
        }

        (ok, message), home = self._save_blossom_response_for_test(descriptor, ciphertext)
        self.assertFalse(ok)
        self.assertIn("AES-GCM authentication", message)
        self.assertFalse((home / "Downloads").exists())
        self.assertEqual(list(self.alice.state_dir.glob(".download-*")), [])

    def test_blossom_download_rejects_body_larger_than_declared_ciphertext(self):
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM

        plain = b"bounded download"
        key, nonce = os.urandom(32), os.urandom(12)
        ciphertext = AESGCM(key).encrypt(nonce, plain, None)
        descriptor = {
            "transport": "blossom", "name": "notes.txt", "content_type": "text/plain",
            "size": len(plain), "cipher_size": len(ciphertext),
            "sha256": hashlib.sha256(ciphertext).hexdigest(),
            "plain_sha256": hashlib.sha256(plain).hexdigest(),
            "url": "https://cdn.example.test/blob/notes", "is_archive": False,
            "key": base64.urlsafe_b64encode(key).decode().rstrip("="),
            "nonce": base64.urlsafe_b64encode(nonce).decode().rstrip("="),
        }

        (ok, message), home = self._save_blossom_response_for_test(
            descriptor, ciphertext + b"oversized"
        )
        self.assertFalse(ok)
        self.assertIn("exceeds its declared size", message)
        self.assertFalse((home / "Downloads").exists())
        self.assertEqual(list(self.alice.state_dir.glob(".download-*")), [])

    def test_folder_attachment_is_a_bounded_zip(self):
        folder = Path(self.paths[0]) / "project"
        folder.mkdir()
        (folder / "readme.txt").write_text("hello", encoding="utf-8")
        attachment = friends.read_private_attachment(folder, is_folder=True)
        self.assertEqual(attachment["name"], "project.zip")
        self.assertTrue(attachment["is_archive"])
        archive_bytes = base64.b64decode(attachment["data"])
        with zipfile.ZipFile(BytesIO(archive_bytes)) as archive:
            self.assertEqual(archive.namelist(), ["readme.txt"])
            self.assertEqual(archive.read("readme.txt"), b"hello")

    def test_folder_with_spaces_sends_as_encrypted_zip_and_saves_for_recipient(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.bob, self.alice)
        folder = Path(self.paths[0]) / "project files"
        folder.mkdir()
        (folder / "read me.txt").write_text("private folder contents", encoding="utf-8")
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "", "", str(folder), True)
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 1)
        self.assertNotIn("private folder contents", json.dumps(published[0]))
        opened = self.bob._global_dm_from_event(published[0])
        self.assertIsNotNone(opened)
        attachment = opened["attachments"][0]
        self.assertEqual(attachment["name"], "project files.zip")
        self.assertTrue(attachment["is_archive"])
        self.bob.state["global"]["messages"].append(opened)
        download_home = Path(self.paths[1]) / "recipient-home"
        with patch.object(Path, "home", return_value=download_home):
            saved, destination = self.bob.save_attachment(opened["id"])
        self.assertTrue(saved, destination)
        archive_path = Path(destination)
        self.assertEqual(archive_path.name, "project files.zip")
        with zipfile.ZipFile(archive_path) as archive:
            self.assertEqual(archive.namelist(), ["read me.txt"])
            self.assertEqual(archive.read("read me.txt"), b"private folder contents")
        self.assertEqual(archive_path.stat().st_mode & 0o777, 0o600)

    def test_save_attachment_uses_private_download_file_and_preserves_collisions(self):
        source = Path(self.paths[0]) / "notes.txt"
        source.write_bytes(b"private attachment")
        attachment = friends.read_private_attachment(source)
        self.alice.state["global"]["messages"].append({
            "id": "attachment-event", "public_key": self.key(self.bob), "handle": "Friend",
            "text": "Shared notes.txt", "attachments": [attachment], "incoming": True,
        })
        with patch.object(Path, "home", return_value=Path(self.paths[1])):
            ok, first_path = self.alice.save_attachment("attachment-event")
            ok_again, second_path = self.alice.save_attachment("attachment-event")
        self.assertTrue(ok, first_path)
        self.assertTrue(ok_again, second_path)
        self.assertEqual(Path(first_path).read_bytes(), b"private attachment")
        self.assertEqual(Path(second_path).read_bytes(), b"private attachment")
        self.assertNotEqual(first_path, second_path)
        self.assertEqual(Path(first_path).stat().st_mode & 0o777, 0o600)

    def test_private_attachment_reader_rejects_symlink_files_and_skips_folder_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            outside = base / "outside.txt"
            outside.write_text("secret", encoding="utf-8")
            link = base / "linked.txt"
            link.symlink_to(outside)
            with self.assertRaises(ValueError):
                friends.read_private_attachment(link)

            folder = base / "folder"
            folder.mkdir()
            (folder / "safe.txt").write_text("safe", encoding="utf-8")
            (folder / "linked.txt").symlink_to(outside)
            nested = base / "outside-folder"
            nested.mkdir()
            (nested / "secret.txt").write_text("secret", encoding="utf-8")
            (folder / "linked-folder").symlink_to(nested, target_is_directory=True)
            attachment = friends.read_private_attachment(folder, is_folder=True)
            with zipfile.ZipFile(BytesIO(base64.b64decode(attachment["data"]))) as archive:
                self.assertEqual(archive.namelist(), ["safe.txt"])
                self.assertEqual(archive.read("safe.txt"), b"safe")

    def test_folder_archiver_rejects_file_replaced_by_symlink_during_open(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            folder = base / "selected"
            folder.mkdir()
            selected_file = folder / "notes.txt"
            selected_file.write_text("selected content", encoding="utf-8")
            outside = base / "outside.txt"
            outside.write_text("outside secret", encoding="utf-8")
            original_open = os.open
            replaced = {"done": False}

            def replace_then_open(path, flags, *args, **kwargs):
                if path == "notes.txt" and kwargs.get("dir_fd") is not None and not replaced["done"]:
                    selected_file.unlink()
                    selected_file.symlink_to(outside)
                    replaced["done"] = True
                return original_open(path, flags, *args, **kwargs)

            with patch.object(friends.os, "open", side_effect=replace_then_open):
                with self.assertRaises(ValueError):
                    friends.read_private_attachment(folder, is_folder=True)
            self.assertTrue(replaced["done"])

    def test_large_folder_preparation_skips_symlinks_before_encrypted_upload(self):
        folder = Path(self.paths[0]) / "large-folder"
        folder.mkdir()
        (folder / "safe.bin").write_bytes(os.urandom(32 * 1024))
        outside = Path(self.paths[0]) / "outside-secret.bin"
        outside.write_bytes(b"outside" * 4096)
        (folder / "linked.bin").symlink_to(outside)
        (folder / "linked-directory").symlink_to(Path(self.paths[0]), target_is_directory=True)
        observed = {}

        def inspect_upload(path, name, content_type, is_archive=False):
            with zipfile.ZipFile(path) as archive:
                observed["names"] = archive.namelist()
            observed["name"] = name
            return {"transport": "test"}

        with patch.object(self.alice, "_upload_private_attachment", side_effect=inspect_upload):
            result = self.alice._prepare_private_attachment(folder, is_folder=True)
        self.assertEqual(result["transport"], "test")
        self.assertEqual(observed["names"], ["safe.bin"])
        self.assertEqual(observed["name"], "large-folder.zip")

    def test_legacy_private_transport_carries_attachment_and_filename_fallback(self):
        self.make_friends(self.alice, self.bob)
        path = Path(self.paths[0]) / "tiny.txt"
        path.write_bytes(b"old peer compatible")
        published = []
        with patch.object(
            self.alice, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "", "", str(path))
        self.assertTrue(ok, message)
        received = self.bob._global_dm_from_event(published[0])
        self.assertEqual(received["text"], "Shared tiny.txt")
        self.assertEqual(base64.b64decode(received["attachments"][0]["data"]), b"old peer compatible")

    def test_failed_dm_is_not_reported_sent_but_is_saved_locally(self):
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
        self.assertEqual(self.alice.last_sent_message_id, self.alice.state["global"]["messages"][0]["id"])
        self.assertEqual(self.alice.state["global"]["messages"][0]["text"], "keep as unconfirmed")
        self.assertEqual(self.alice.state["global"]["messages"][0]["sendState"], "Unconfirmed · retry")
        self.assertEqual(self.alice.state["global"]["messages"][0]["retry_actions"][0]["kind"], "nip17_rumor")
        public_message = self.alice.get_full_status()["global_messages"][0]
        self.assertTrue(public_message["retryable"])
        self.assertNotIn("retry_actions", public_message)
        pre_upgrade_failure = dict(self.alice.state["global"]["messages"][0])
        pre_upgrade_failure.pop("retry_at", None)
        pre_upgrade_failure.pop("retry_attempts", None)
        upgraded_failure = self.alice._normalize_global_message(pre_upgrade_failure)
        self.assertEqual(upgraded_failure["retry_attempts"], 0)
        self.assertGreater(upgraded_failure["retry_at"], friends.now_seconds())

    def test_due_private_send_retries_same_authenticated_payload_automatically(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: (published.append(event) or (len(published) > 1, {})),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "auto retry me")
            self.assertFalse(ok, message)
            target_id = self.alice.last_sent_message_id
            self.alice._persist_outgoing_message({"id": target_id, "retry_at": friends.now_seconds() - 1})
            attempted, delivered = self.alice.retry_pending_private_messages()
        self.assertEqual((attempted, delivered), (1, 1))
        first_rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[0])
        retry_rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[1])
        self.assertEqual(first_rumor["id"], retry_rumor["id"])
        self.assertEqual(retry_rumor["id"], target_id)
        saved = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(saved["sendState"], "Sent")
        self.assertEqual(saved["retry_actions"], [])
        self.assertEqual(saved["retry_at"], 0)
        self.assertEqual(self.alice.retry_pending_private_messages(), (0, 0))

    def test_private_automatic_retry_uses_backoff_and_stops_after_limit(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        with patch.object(self.alice, "_publish_event_to_relays", return_value=(False, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "bounded retry")
            self.assertFalse(ok, message)
            target_id = self.alice.last_sent_message_id
            for attempt in range(1, friends.MAX_PRIVATE_AUTO_RETRIES + 1):
                self.alice._persist_outgoing_message({"id": target_id, "retry_at": friends.now_seconds() - 1})
                self.assertEqual(self.alice.retry_pending_private_messages(), (1, 0))
                saved = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
                self.assertEqual(saved["retry_attempts"], attempt)
                if attempt < friends.MAX_PRIVATE_AUTO_RETRIES:
                    self.assertGreater(saved["retry_at"], friends.now_seconds())
                else:
                    self.assertEqual(saved["retry_at"], 0)
            self.alice._persist_outgoing_message({"id": target_id, "retry_at": friends.now_seconds() - 1})
            self.assertEqual(self.alice.retry_pending_private_messages(), (0, 0))

    def test_automatic_retry_recovers_a_process_interrupted_during_initial_send(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        with patch.object(self.alice, "_publish_event_to_relays", return_value=(False, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "recover interrupted send")
        self.assertFalse(ok, message)
        target_id = self.alice.last_sent_message_id
        self.alice._persist_outgoing_message({
            "id": target_id,
            "sendState": "Sending…",
            "retry_at": 0,
            "timestamp": friends.now_seconds() - friends.PRIVATE_SEND_STALE_SECONDS - 1,
        })
        with patch.object(self.alice, "_publish_event_to_relays", return_value=(True, {})) as publish:
            self.assertEqual(self.alice.retry_pending_private_messages(), (1, 1))
        publish.assert_called_once()
        saved = next(item for item in self.alice.state["global"]["messages"] if item["id"] == target_id)
        self.assertEqual(saved["sendState"], "Sent")

    def test_retry_failed_legacy_dm_republishes_same_signed_event(self):
        self.make_friends(self.alice, self.bob)
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: (published.append(event) or (len(published) > 1, {})),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "legacy retry")
            self.assertFalse(ok, message)
            target_id = self.alice.state["global"]["messages"][-1]["id"]
            ok, message = self.alice.retry_private_message(target_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 2)
        self.assertEqual(published[0]["id"], published[1]["id"])
        self.assertEqual(self.alice.state["global"]["messages"][-1]["sendState"], "Sent")
        self.assertEqual(self.alice.state["global"]["messages"][-1]["retry_actions"], [])
        self.assertTrue(self.bob._ingest_global_dm(published[1]))
        self.assertEqual(len(self.bob.state["global"]["messages"]), 1)

    def test_retry_failed_nip17_dm_reuses_signed_rumor_after_restart(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, _relays: (published.append(event) or (len(published) > 1, {})),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "modern retry")
        self.assertFalse(ok, message)
        target_id = self.alice.state["global"]["messages"][-1]["id"]
        restored = friends.FriendsEngine(state_dir=self.paths[0])
        with patch.object(
            restored, "_publish_event_to_relays",
            side_effect=lambda event, _relays: (published.append(event) or True, {}),
        ):
            ok, message = restored.retry_private_message(target_id)
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 2)
        first_rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[0])
        second_rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[1])
        self.assertEqual(first_rumor["id"], second_rumor["id"])
        self.assertEqual(second_rumor["id"], target_id)
        self.assertTrue(self.bob._ingest_global_dm(published[1]))
        self.assertEqual(len(self.bob.state["global"]["messages"]), 1)

    def test_group_partial_delivery_retries_only_unconfirmed_member(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        self.advertise_modern(self.alice, self.bob)
        group_id = "group-retry"
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "name": "Retry crew",
            "members": {self.key(self.alice): {}, self.key(self.bob): {}, self.key(self.carol): {}},
        }
        published = []

        def acknowledge_bob_only(event, _relays):
            published.append(event)
            recipient = next(tag[1] for tag in event.get("tags", []) if len(tag) > 1 and tag[0] == "p")
            return recipient == self.key(self.bob), {}

        with patch.object(self.alice, "_publish_event_to_relays", side_effect=acknowledge_bob_only):
            ok, message = self.alice.send_group_message(group_id, "group retry")
        self.assertFalse(ok)
        self.assertIn("1 of 2", message)
        target = next(item for item in self.alice.state["global"]["messages"] if item.get("group_id") == group_id)
        target_id = target["id"]
        self.assertEqual(self.alice.last_sent_message_id, target_id)
        self.assertEqual(target["sendState"], "Partial · retry")
        self.assertEqual([action["recipient"] for action in target["retry_actions"]], [self.key(self.carol)])
        first_rumor = friends.unwrap_nip17_gift_wrap(self.bob.state["global_identity"]["secret_key"], published[0])
        self.assertEqual(friends.app_envelope_from_rumor(first_rumor)["text"], "group retry")

        restored = friends.FriendsEngine(state_dir=self.paths[0])
        restored._persist_outgoing_message({"id": target_id, "retry_at": friends.now_seconds() - 1})
        retried = []
        with patch.object(
            restored, "_publish_event_to_relays",
            side_effect=lambda event, _relays: (retried.append(event) or True, {}),
        ):
            attempted, delivered = restored.retry_pending_private_messages()
        self.assertEqual((attempted, delivered), (1, 1))
        self.assertEqual(len(retried), 1)
        retry_recipient = next(tag[1] for tag in retried[0]["tags"] if len(tag) > 1 and tag[0] == "p")
        self.assertEqual(retry_recipient, self.key(self.carol))
        self.assertEqual(restored.state["global"]["messages"][-1]["sendState"], "Sent")

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

    def test_private_relay_publish_waits_for_all_acknowledgements_concurrently(self):
        import threading
        import time

        barrier = threading.Barrier(3)
        acknowledged_urls = []

        class ParallelRelay:
            def __init__(self, url, timeout): self.event = None; self.url = url
            def __enter__(self): return self
            def __exit__(self, *_args): return False
            def send_json(self, value): self.event = value[1]
            def recv_json(self, _timeout):
                barrier.wait(timeout=1.0)
                acknowledged_urls.append(self.url)
                return ["OK", self.event["id"], True, "accepted"]

        event = {"id": "parallel-event", "kind": friends.NIP59_GIFT_WRAP_KIND}
        started = time.monotonic()
        with patch.object(friends, "WebSocketClient", ParallelRelay):
            ok, status = self.alice._publish_event_to_relays(event, friends.NIP17_DM_RELAYS)
        self.assertTrue(ok)
        self.assertTrue(any(item["accepted"] and item["acknowledged"] for item in status.values()))
        self.assertEqual(set(acknowledged_urls), set(friends.NIP17_DM_RELAYS))
        self.assertEqual(set(status), set(friends.NIP17_DM_RELAYS))
        self.assertLess(time.monotonic() - started, 0.25)

    def test_dm_relay_metadata_lookup_queries_relays_in_parallel(self):
        import threading
        import time

        barrier = threading.Barrier(len(friends.GLOBAL_RELAYS))

        class MetadataRelay:
            def __init__(self, _url, timeout): self.sub_id = None
            def __enter__(self): return self
            def __exit__(self, *_args): return False
            def send_json(self, value): self.sub_id = value[1]
            def recv_json(self, _timeout):
                barrier.wait(timeout=0.5)
                return ["EOSE", self.sub_id]

        started = time.monotonic()
        with patch.object(friends, "WebSocketClient", MetadataRelay):
            relays = self.alice._fetch_nip17_dm_relays(self.key(self.bob))
        self.assertEqual(relays, [])
        self.assertLess(time.monotonic() - started, 0.75)

    def test_self_copy_never_creates_incoming_notification(self):
        self.make_friends(self.alice, self.bob)
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"],
            [self.key(self.bob)], "hello", app_envelope={"v": 3, "type": "direct", "text": "hello", "media": []},
        )
        self_copy = friends.wrap_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], self.key(self.alice), rumor,
        )
        self.assertFalse(self.alice._ingest_global_dm(self_copy))
        self.assertEqual(self.alice.state["global"].get("messages", []), [])
        self.assertEqual(self.alice.state.get("events", []), [])

    def test_pinned_conversation_is_encrypted_state_persistent_and_unpinning_works(self):
        self.make_friends(self.alice, self.bob)
        bob_key = self.key(self.bob)
        ok, message = self.alice.set_conversation_pinned("friend", bob_key, True)
        self.assertTrue(ok, message)
        self.assertIn("friend:" + bob_key, self.alice.get_full_status()["global_pinned_conversations"])

        group_id = "local-room"
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "name": "Private room",
            "members": {self.key(self.alice): {}, bob_key: {}},
        }
        ok, message = self.alice.set_conversation_pinned("group", group_id, True)
        self.assertTrue(ok, message)
        self.assertIn("group:" + group_id, self.alice.get_full_status()["global_pinned_conversations"])

        reopened = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertIn("friend:" + bob_key, reopened.get_full_status()["global_pinned_conversations"])
        self.assertIn("group:" + group_id, reopened.get_full_status()["global_pinned_conversations"])
        ok, message = reopened.set_conversation_pinned("friend", bob_key, False)
        self.assertTrue(ok, message)
        self.assertNotIn("friend:" + bob_key, reopened.get_full_status()["global_pinned_conversations"])

    def test_pin_rejects_nonfriend_and_unknown_group(self):
        ok, message = self.alice.set_conversation_pinned("friend", self.key(self.bob), True)
        self.assertFalse(ok)
        self.assertIn("not available", message)
        ok, message = self.alice.set_conversation_pinned("group", "missing-group", True)
        self.assertFalse(ok)
        self.assertIn("not available", message)
        self.alice.state["global"]["groups"]["group-x"] = {"members": {self.key(self.bob): {}}}
        ok, message = self.alice.set_conversation_pinned("group", "group-x", True)
        self.assertFalse(ok)
        self.assertIn("private group", message)

    def test_pin_limit_is_bounded(self):
        self.make_friends(self.alice, self.bob)
        self.alice.state["global"]["pinned_conversations"] = [f"group:old-{index}" for index in range(friends.MAX_PINNED_CONVERSATIONS)]
        ok, message = self.alice.set_conversation_pinned("friend", self.key(self.bob), True)
        self.assertFalse(ok)
        self.assertIn("pin up to", message)

    def test_muted_conversation_state_persists_and_can_be_cleared(self):
        self.make_friends(self.alice, self.bob)
        bob_key = self.key(self.bob)
        ok, message = self.alice.set_conversation_muted("friend", bob_key, True)
        self.assertTrue(ok, message)
        group_id = "muted-room"
        self.alice.state["global"]["groups"][group_id] = {
            "id": group_id, "name": "Muted room",
            "members": {self.key(self.alice): {}, bob_key: {}},
        }
        ok, message = self.alice.set_conversation_muted("group", group_id, True)
        self.assertTrue(ok, message)
        reopened = friends.FriendsEngine(state_dir=self.paths[0])
        self.assertIn("friend:" + bob_key, reopened.get_full_status()["global_muted_conversations"])
        self.assertIn("group:" + group_id, reopened.get_full_status()["global_muted_conversations"])
        ok, message = reopened.set_conversation_muted("friend", bob_key, False)
        self.assertTrue(ok, message)
        ok, message = reopened.set_conversation_muted("group", group_id, False)
        self.assertTrue(ok, message)
        self.assertNotIn("friend:" + bob_key, reopened.get_full_status()["global_muted_conversations"])
        self.assertNotIn("group:" + group_id, reopened.get_full_status()["global_muted_conversations"])

    def test_muted_dm_keeps_message_and_unread_count_but_suppresses_toast_event(self):
        self.make_friends(self.alice, self.bob)
        alice_key = self.key(self.alice)
        self.assertTrue(self.bob.set_conversation_muted("friend", alice_key, True)[0])
        sent = []
        with patch.object(self.alice, "_publish_global_event", side_effect=lambda event: sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "quiet incoming")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        self.assertEqual(self.bob.state["global"].get("messages", [])[-1]["text"], "quiet incoming")
        self.assertEqual(self.bob._global_unread_counts(), {"friend:" + alice_key: 1})
        self.assertEqual(self.bob.state.get("events", []), [])

        self.assertTrue(self.bob.set_conversation_muted("friend", alice_key, False)[0])
        with patch.object(self.alice, "_publish_global_event", side_effect=lambda event: sent.append(event) or (True, {})):
            ok, message = self.alice.send_dm(self.key(self.bob), "unmuted incoming")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(sent[-1]))
        self.assertEqual(len(self.bob.state.get("events", [])), 1)

    def test_unread_count_is_local_persistent_and_clears_when_direct_chat_is_opened(self):
        self.make_friends(self.alice, self.bob)
        published = []
        with patch.object(
            self.alice, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "new message")
        self.assertTrue(ok, message)
        self.assertTrue(self.bob._ingest_global_dm(published[-1]))
        cursor_key = "friend:" + self.key(self.alice)
        self.assertEqual(self.bob._global_unread_counts(), {cursor_key: 1})
        time_before_read = self.bob.state["global"]["messages"][-1]["received_at_ms"]
        ok, message = self.bob.mark_conversation_read("friend", self.key(self.alice))
        self.assertTrue(ok, message)
        self.assertGreaterEqual(self.bob.state["global"]["read_cursors"][cursor_key], time_before_read)
        self.assertEqual(self.bob._global_unread_counts(), {})
        restarted = friends.FriendsEngine(state_dir=self.paths[1])
        self.assertEqual(restarted._global_unread_counts(), {})

        import time
        time.sleep(0.002)
        with patch.object(
            self.alice, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "another message")
        self.assertTrue(ok, message)
        self.assertTrue(restarted._ingest_global_dm(published[-1]))
        self.assertEqual(restarted._global_unread_counts(), {cursor_key: 1})

    def test_unread_state_is_scoped_to_each_group_and_direct_chat(self):
        self.make_friends(self.alice, self.bob)
        group_id = "a" * 24
        own_key = self.key(self.bob)
        peer_key = self.key(self.alice)
        self.bob.state["global"]["groups"][group_id] = {
            "id": group_id, "name": "Room", "members": {own_key: {}, peer_key: {}},
        }
        self.bob.state["global"]["messages"] = [
            {"id": "1" * 64, "public_key": peer_key, "conversation_key": "", "group_id": group_id,
             "message_type": "group_message", "timestamp": 1, "received_at_ms": 1000, "incoming": True, "text": "group"},
            {"id": "2" * 64, "public_key": peer_key, "conversation_key": peer_key, "group_id": "",
             "message_type": "direct", "timestamp": 1, "received_at_ms": 1000, "incoming": True, "text": "direct"},
            {"id": "3" * 64, "public_key": peer_key, "conversation_key": "", "group_id": group_id,
             "message_type": "reaction", "timestamp": 2, "received_at_ms": 2000, "incoming": True, "text": "❤️"},
        ]
        self.assertEqual(self.bob._global_unread_counts(), {"group:" + group_id: 1, "friend:" + peer_key: 1})
        self.assertTrue(self.bob.mark_conversation_read("group", group_id)[0])
        self.assertEqual(self.bob._global_unread_counts(), {"friend:" + peer_key: 1})

    def test_upgrade_marks_existing_history_read_and_discards_invalid_cursors(self):
        peer_key = self.key(self.alice)
        legacy_state = {
            "global_identity": self.bob.state["global_identity"],
            "global": {
                "friendships": {peer_key: {"status": "friends", "handle": "Alice"}},
                "messages": [{
                    "id": "4" * 64, "public_key": peer_key, "conversation_key": peer_key,
                    "group_id": "", "timestamp": 100, "incoming": True, "text": "old",
                }],
                "private_history_cursors": {
                    friends.GLOBAL_RELAYS[0]: {"until": 123, "done": False},
                    friends.GLOBAL_RELAYS[1]: {"until": "invalid", "done": True},
                    "wss://attacker.invalid": {"until": 999, "done": False},
                },
            },
        }
        upgraded = self.bob._migrate_state(legacy_state)
        self.assertEqual(upgraded["global"]["read_cursors"], {"friend:" + peer_key: 100000})
        self.assertEqual(upgraded["global"]["private_history_cursors"], {
            friends.GLOBAL_RELAYS[0]: {"until": 123, "done": False},
            friends.GLOBAL_RELAYS[1]: {"until": 0, "done": True},
        })
        legacy_state["global"]["read_cursors"] = {"friend:" + peer_key: 100000, "friend:bad": 500000}
        upgraded = self.bob._migrate_state(legacy_state)
        self.assertEqual(upgraded["global"]["read_cursors"], {"friend:" + peer_key: 100000})

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
