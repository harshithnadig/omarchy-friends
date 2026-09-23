import socket
import struct
import unittest
from pathlib import Path
import sys
from unittest.mock import patch

BIN_DIR = Path(__file__).parent.parent / "bin"
sys.path.insert(0, str(BIN_DIR))

import omarchy_friends_global as transport


def relay_frame(opcode, payload=b"", final=True):
    payload = bytes(payload)
    first = (0x80 if final else 0) | (opcode & 0x0F)
    length = len(payload)
    if length < 126:
        header = bytes((first, length))
    elif length < 65536:
        header = bytes((first, 126)) + struct.pack("!H", length)
    else:
        header = bytes((first, 127)) + struct.pack("!Q", length)
    return header + payload


class FakeSocket:
    def __init__(self, chunks=()):
        self.chunks = list(chunks)
        self.timeouts = []
        self.sent = []
        self.recv_calls = 0

    def settimeout(self, value):
        self.timeouts.append(value)

    def recv(self, _length):
        self.recv_calls += 1
        if not self.chunks:
            return b""
        return self.chunks.pop(0)

    def sendall(self, payload):
        self.sent.append(bytes(payload))

    def close(self):
        pass


class WebSocketResourceLimitTests(unittest.TestCase):
    @staticmethod
    def client(buffer=b"", chunks=()):
        client = transport.WebSocketClient.__new__(transport.WebSocketClient)
        client.url = "wss://relay.example"
        client.timeout = 1.0
        client.sock = FakeSocket(chunks)
        client._buffer = bytes(buffer)
        return client

    def test_valid_fragmented_json_is_reassembled(self):
        payload = (
            relay_frame(0x1, b'{"ok":', final=False)
            + relay_frame(0x0, b'true}', final=True)
        )
        client = self.client(buffer=payload)
        self.assertEqual(client.recv_json(), {"ok": True})

    def test_fragment_count_cap_rejects_many_continuations(self):
        payload = (
            relay_frame(0x1, b"{", final=False)
            + relay_frame(0x0, b" ", final=False)
            + relay_frame(0x0, b"}", final=True)
        )
        client = self.client(buffer=payload)
        with patch.object(transport, "MAX_WEBSOCKET_FRAGMENTS", 2):
            with self.assertRaisesRegex(ValueError, "fragments too large"):
                client.recv_json()

    def test_cumulative_fragment_bytes_are_bounded(self):
        payload = (
            relay_frame(0x1, b"abc", final=False)
            + relay_frame(0x0, b"def", final=True)
        )
        client = self.client(buffer=payload)
        with patch.object(transport, "MAX_WEBSOCKET_MESSAGE_BYTES", 5):
            with self.assertRaisesRegex(ValueError, "fragments too large"):
                client.recv_json()

    def test_single_frame_limit_is_checked_before_payload_acceptance(self):
        client = self.client(buffer=relay_frame(0x1, b"abc", final=True))
        with patch.object(transport, "MAX_WEBSOCKET_FRAME_BYTES", 2):
            with self.assertRaisesRegex(ValueError, "relay frame too large"):
                client.recv_json()

    def test_excessive_json_nesting_is_malformed_relay_value_error(self):
        client = self.client(buffer=relay_frame(0x1, b"[" * 100_000 + b"0" + b"]" * 100_000))
        with patch.object(transport, "MAX_WEBSOCKET_FRAME_BYTES", 300_000):
            with patch.object(transport, "MAX_WEBSOCKET_MESSAGE_BYTES", 300_000):
                client.sock.chunks = [client._buffer]
                client._buffer = b""
                with self.assertRaisesRegex(ValueError, "nesting too deep"):
                    client.recv_json()

    def test_fragmented_message_uses_one_overall_read_deadline(self):
        # The first socket read supplies one non-final fragment. By the time the
        # next frame header is needed, the original recv_json deadline has
        # elapsed. A per-fragment timeout reset would incorrectly keep reading.
        first_fragment = relay_frame(0x1, b'{"ok":', final=False)
        client = self.client(chunks=[first_fragment])
        with patch.object(transport.time, "monotonic", side_effect=[0.0, 0.1, 1.1]):
            self.assertIsNone(client.recv_json(timeout=1.0))
        self.assertEqual(client.sock.recv_calls, 1)
        self.assertEqual(len(client.sock.timeouts), 1)
        self.assertGreater(client.sock.timeouts[0], 0)
        self.assertLessEqual(client.sock.timeouts[0], 1.0)

    def test_read_exact_honors_expired_deadline_without_socket_read(self):
        client = self.client(chunks=[b"ignored"])
        with patch.object(transport.time, "monotonic", return_value=2.0):
            with self.assertRaises(socket.timeout):
                client._read_exact(1, deadline=1.0)
        self.assertEqual(client.sock.recv_calls, 0)


if __name__ == "__main__":
    unittest.main()
