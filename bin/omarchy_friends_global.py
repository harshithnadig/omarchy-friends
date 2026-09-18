"""Small, dependency-free Nostr transport for Omarchy Friends.

The Friends plugin deliberately keeps the global layer boring at the wire
level: a persistent pseudonymous secp256k1 identity, a signed presence event,
and tiny signed pings.  This module implements the parts needed by the plugin
without asking users to install Python packages or run a server.
"""

import base64
import hashlib
import json
import os
import secrets
import socket
import ssl
import struct
import time
from urllib.parse import urlsplit


# secp256k1 domain parameters.
FIELD_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
CURVE_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
GENERATOR = (
    55066263022277343669578718895168534326250603453777594175500187360389116729240,
    32670510020758816978083085130507043184471273380659243275938904335757337482424,
)


def _point_add(left, right):
    if left is None:
        return right
    if right is None:
        return left
    x1, y1 = left
    x2, y2 = right
    if x1 == x2:
        if (y1 + y2) % FIELD_P == 0:
            return None
        slope = (3 * x1 * x1) * pow(2 * y1, FIELD_P - 2, FIELD_P) % FIELD_P
    else:
        slope = (y2 - y1) * pow(x2 - x1, FIELD_P - 2, FIELD_P) % FIELD_P
    x3 = (slope * slope - x1 - x2) % FIELD_P
    y3 = (slope * (x1 - x3) - y1) % FIELD_P
    return x3, y3


def _point_mul(scalar, point=GENERATOR):
    scalar %= CURVE_N
    result = None
    addend = point
    while scalar:
        if scalar & 1:
            result = _point_add(result, addend)
        addend = _point_add(addend, addend)
        scalar >>= 1
    return result


def _tagged_hash(tag, payload):
    tag_hash = hashlib.sha256(tag.encode("ascii")).digest()
    return hashlib.sha256(tag_hash + tag_hash + payload).digest()


def _lift_x(x_value):
    if not 0 <= x_value < FIELD_P:
        return None
    y_square = (pow(x_value, 3, FIELD_P) + 7) % FIELD_P
    y_value = pow(y_square, (FIELD_P + 1) // 4, FIELD_P)
    if (y_value * y_value - y_square) % FIELD_P != 0:
        return None
    if y_value & 1:
        y_value = FIELD_P - y_value
    return x_value, y_value


def generate_keypair(secret_key=None):
    """Return a BIP-340-compatible private key and x-only public key."""
    if secret_key is None:
        secret_key = secrets.randbelow(CURVE_N - 1) + 1
    if isinstance(secret_key, str):
        secret_key = int(secret_key, 16)
    if not isinstance(secret_key, int) or not 1 <= secret_key < CURVE_N:
        raise ValueError("invalid secp256k1 secret key")
    point = _point_mul(secret_key)
    return {
        "secret_key": f"{secret_key:064x}",
        "public_key": f"{point[0]:064x}",
    }


def schnorr_sign(message_hash, secret_key):
    """Create a BIP-340 Schnorr signature for a 32-byte message hash."""
    if isinstance(message_hash, str):
        message_hash = bytes.fromhex(message_hash)
    if len(message_hash) != 32:
        raise ValueError("Schnorr messages must be 32 bytes")
    secret = int(secret_key, 16) if isinstance(secret_key, str) else secret_key
    if not 1 <= secret < CURVE_N:
        raise ValueError("invalid secp256k1 secret key")
    public_point = _point_mul(secret)
    effective_secret = secret if public_point[1] % 2 == 0 else CURVE_N - secret
    public_x = public_point[0].to_bytes(32, "big")
    # BIP-340's auxiliary randomness means a compromised process cannot make
    # every signature's nonce predictable from the secret key alone.
    aux = secrets.token_bytes(32)
    masked = bytes(a ^ b for a, b in zip(
        effective_secret.to_bytes(32, "big"),
        _tagged_hash("BIP0340/aux", aux),
    ))
    nonce_input = masked + public_x + message_hash
    nonce = int.from_bytes(_tagged_hash("BIP0340/nonce", nonce_input), "big") % CURVE_N
    if nonce == 0:
        # This is astronomically unlikely; using fresh auxiliary randomness is
        # the correct recovery rather than emitting an invalid signature.
        return schnorr_sign(message_hash, secret)
    nonce_point = _point_mul(nonce)
    effective_nonce = nonce if nonce_point[1] % 2 == 0 else CURVE_N - nonce
    challenge = int.from_bytes(
        _tagged_hash(
            "BIP0340/challenge",
            nonce_point[0].to_bytes(32, "big") + public_x + message_hash,
        ),
        "big",
    ) % CURVE_N
    signature_s = (effective_nonce + challenge * effective_secret) % CURVE_N
    return nonce_point[0].to_bytes(32, "big") + signature_s.to_bytes(32, "big")


def schnorr_verify(message_hash, public_key, signature):
    """Verify a BIP-340 signature; malformed remote data simply fails closed."""
    try:
        if isinstance(message_hash, str):
            message_hash = bytes.fromhex(message_hash)
        if isinstance(public_key, str):
            public_key = bytes.fromhex(public_key)
        if isinstance(signature, str):
            signature = bytes.fromhex(signature)
        if len(message_hash) != 32 or len(public_key) != 32 or len(signature) != 64:
            return False
        x_value = int.from_bytes(public_key, "big")
        r_value = int.from_bytes(signature[:32], "big")
        s_value = int.from_bytes(signature[32:], "big")
        if x_value >= FIELD_P or r_value >= FIELD_P or s_value >= CURVE_N:
            return False
        public_point = _lift_x(x_value)
        if public_point is None:
            return False
        challenge = int.from_bytes(
            _tagged_hash("BIP0340/challenge", signature[:32] + public_key + message_hash),
            "big",
        ) % CURVE_N
        # s*G - e*P, expressed with the inverse scalar modulo the group order.
        candidate = _point_add(_point_mul(s_value), _point_mul(CURVE_N - challenge, public_point))
        return candidate is not None and candidate[1] % 2 == 0 and candidate[0] == r_value
    except (TypeError, ValueError, OverflowError):
        return False


def build_event(secret_key, kind, tags, content, created_at=None):
    """Build and sign one NIP-01 event."""
    identity = generate_keypair(secret_key)
    created_at = int(time.time()) if created_at is None else int(created_at)
    clean_tags = []
    for tag in tags or []:
        if isinstance(tag, (list, tuple)) and tag and all(isinstance(item, str) for item in tag):
            clean_tags.append(list(tag))
    serialized = [
        0,
        identity["public_key"],
        created_at,
        int(kind),
        clean_tags,
        str(content),
    ]
    serialized_bytes = json.dumps(
        serialized,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    event_id = hashlib.sha256(serialized_bytes).digest()
    signature = schnorr_sign(event_id, secret_key)
    return {
        "id": event_id.hex(),
        "pubkey": identity["public_key"],
        "created_at": created_at,
        "kind": int(kind),
        "tags": clean_tags,
        "content": str(content),
        "sig": signature.hex(),
    }


def verify_event(event):
    """Verify event id, signature, and the bounded shape expected from relays."""
    try:
        if not isinstance(event, dict):
            return False
        pubkey = event["pubkey"]
        event_id = event["id"]
        created_at = int(event["created_at"])
        kind = int(event["kind"])
        tags = event["tags"]
        content = event["content"]
        if not isinstance(pubkey, str) or len(pubkey) != 64:
            return False
        if not isinstance(event_id, str) or len(event_id) != 64:
            return False
        if not isinstance(tags, list) or not isinstance(content, str) or not 0 <= kind <= 65535:
            return False
        serialized = json.dumps(
            [0, pubkey, created_at, kind, tags, content],
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        calculated = hashlib.sha256(serialized).digest()
        return calculated.hex() == event_id and schnorr_verify(calculated, pubkey, event["sig"])
    except (KeyError, TypeError, ValueError, OverflowError):
        return False


class WebSocketClient:
    """Minimal RFC 6455 client for wss:// relay endpoints."""

    def __init__(self, url, timeout=4.0):
        self.url = url
        self.timeout = timeout
        self.sock = None
        self._buffer = b""
        self._connect()

    def _connect(self):
        parsed = urlsplit(self.url)
        if parsed.scheme not in ("ws", "wss") or not parsed.hostname:
            raise ValueError("relay must be a ws:// or wss:// URL")
        port = parsed.port or (443 if parsed.scheme == "wss" else 80)
        path = parsed.path or "/"
        if parsed.query:
            path += "?" + parsed.query
        sock = socket.create_connection((parsed.hostname, port), timeout=self.timeout)
        if parsed.scheme == "wss":
            context = ssl.create_default_context()
            sock = context.wrap_socket(sock, server_hostname=parsed.hostname)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        host_header = parsed.hostname
        if (parsed.scheme == "ws" and port != 80) or (parsed.scheme == "wss" and port != 443):
            host_header += f":{port}"
        request = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host_header}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        ).encode("ascii")
        sock.sendall(request)
        response = b""
        sock.settimeout(self.timeout)
        while b"\r\n\r\n" not in response and len(response) < 16384:
            chunk = sock.recv(4096)
            if not chunk:
                break
            response += chunk
        if b"\r\n\r\n" not in response:
            sock.close()
            raise OSError("relay websocket handshake returned no headers")
        header_bytes, remainder = response.split(b"\r\n\r\n", 1)
        header = header_bytes.decode("latin1", "replace")
        if not header.startswith("HTTP/1.1 101"):
            sock.close()
            raise OSError(f"relay websocket handshake failed: {header.splitlines()[0] if header else 'empty response'}")
        response_headers = {}
        for line in header.split("\r\n")[1:]:
            if ":" in line:
                name, value = line.split(":", 1)
                response_headers[name.strip().lower()] = value.strip()
        expected_accept = base64.b64encode(
            hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()
        ).decode("ascii")
        if response_headers.get("sec-websocket-accept") != expected_accept:
            sock.close()
            raise OSError("relay websocket handshake returned an invalid accept key")
        self._buffer = remainder
        self.sock = sock

    def _send_frame(self, opcode, payload=b""):
        if self.sock is None:
            raise OSError("websocket is closed")
        payload = bytes(payload)
        first = 0x80 | (opcode & 0x0F)
        length = len(payload)
        if length < 126:
            header = bytes((first, 0x80 | length))
        elif length < 65536:
            header = bytes((first, 0x80 | 126)) + struct.pack("!H", length)
        else:
            header = bytes((first, 0x80 | 127)) + struct.pack("!Q", length)
        mask = os.urandom(4)
        masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
        self.sock.sendall(header + mask + masked)

    def send_json(self, message):
        self._send_frame(0x1, json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

    def _read_exact(self, length):
        while len(self._buffer) < length:
            chunk = self.sock.recv(max(4096, length - len(self._buffer)))
            if not chunk:
                raise EOFError("relay closed websocket")
            self._buffer += chunk
        result, self._buffer = self._buffer[:length], self._buffer[length:]
        return result

    def recv_json(self, timeout=None):
        if self.sock is None:
            return None
        self.sock.settimeout(self.timeout if timeout is None else max(0.05, timeout))
        fragments = []
        try:
            while True:
                header = self._read_exact(2)
                first, second = header
                opcode = first & 0x0F
                final = bool(first & 0x80)
                masked = bool(second & 0x80)
                length = second & 0x7F
                if length == 126:
                    length = struct.unpack("!H", self._read_exact(2))[0]
                elif length == 127:
                    length = struct.unpack("!Q", self._read_exact(8))[0]
                if length > 1024 * 1024:
                    raise ValueError("relay frame too large")
                mask = self._read_exact(4) if masked else None
                payload = self._read_exact(length)
                if mask:
                    payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
                if opcode == 0x9:
                    self._send_frame(0xA, payload)
                    continue
                if opcode == 0x8:
                    return None
                if opcode == 0x0:
                    fragments.append(payload)
                    if not final:
                        continue
                    payload = b"".join(fragments)
                    fragments = []
                elif opcode == 0x1:
                    if not final:
                        fragments = [payload]
                        continue
                else:
                    continue
                return json.loads(payload.decode("utf-8"))
        except socket.timeout:
            return None

    def close(self):
        sock = self.sock
        if sock is None:
            return
        try:
            # A close frame is best effort; never let shutdown hide a relay result.
            self._send_frame(0x8, struct.pack("!H", 1000))
        except (OSError, ValueError):
            pass
        try:
            sock.close()
        except OSError:
            pass
        self.sock = None

    def __enter__(self):
        return self

    def __exit__(self, _exc_type, _exc_value, _traceback):
        self.close()
