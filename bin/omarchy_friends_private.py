"""NIP-44 v2 + NIP-17/NIP-59 private messaging helpers for Omarchy Friends.

This module is dependency-free and intentionally small. New capable peers use
NIP-17 gift-wrapped kind-14 messages with NIP-44 v2 encryption. Legacy custom
DM decryption remains available only for upgrade compatibility.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import struct
import time

from omarchy_friends_global import (
    CURVE_N,
    _lift_x,
    _point_mul,
    build_event,
    generate_keypair,
    verify_event,
)

NIP44_VERSION = 2
NIP59_SEAL_KIND = 13
NIP17_MESSAGE_KIND = 14
NIP59_GIFT_WRAP_KIND = 1059
NIP44_SALT = b"nip44-v2"
NIP59_RANDOM_WINDOW_SECONDS = 2 * 24 * 60 * 60

MAX_PRIVATE_PLAINTEXT_BYTES = 65535
MAX_PRIVATE_PAYLOAD_CHARS = 87472
MAX_PRIVATE_DECODED_BYTES = 65603


def _secret_scalar(secret_key):
    try:
        value = int(secret_key, 16) if isinstance(secret_key, str) else int(secret_key)
    except (TypeError, ValueError, OverflowError):
        raise ValueError("invalid secp256k1 secret key")
    if not 1 <= value < CURVE_N:
        raise ValueError("invalid secp256k1 secret key")
    return value


def _public_point(public_key):
    try:
        text = str(public_key)
        if len(text) != 64:
            raise ValueError
        point = _lift_x(int(text, 16))
    except (TypeError, ValueError, OverflowError):
        point = None
    if point is None:
        raise ValueError("invalid secp256k1 public key")
    return point


def _shared_x(secret_key, public_key):
    shared = _point_mul(_secret_scalar(secret_key), _public_point(public_key))
    if shared is None:
        raise ValueError("invalid shared point")
    return shared[0].to_bytes(32, "big")


def _hkdf_extract(ikm, salt):
    return hmac.new(salt, ikm, hashlib.sha256).digest()


def _hkdf_expand(prk, info, length):
    if not isinstance(prk, (bytes, bytearray)) or len(prk) != 32:
        raise ValueError("invalid HKDF key")
    if length < 0 or length > 255 * 32:
        raise ValueError("invalid HKDF length")
    result = b""
    previous = b""
    blocks = (length + 31) // 32
    for counter in range(1, blocks + 1):
        previous = hmac.new(bytes(prk), previous + bytes(info) + bytes((counter,)), hashlib.sha256).digest()
        result += previous
    return result[:length]


def nip44_conversation_key(secret_key, public_key):
    """Return the NIP-44 v2 conversation key (HKDF-extract of raw ECDH x)."""
    return _hkdf_extract(_shared_x(secret_key, public_key), NIP44_SALT)


def _calc_padded_len(unpadded_len):
    if not isinstance(unpadded_len, int) or unpadded_len < 1:
        raise ValueError("invalid plaintext length")
    if unpadded_len <= 32:
        return 32
    next_power = 1 << (unpadded_len - 1).bit_length()
    chunk = 32 if next_power <= 256 else next_power // 8
    return chunk * ((unpadded_len - 1) // chunk + 1)


def _pad_plaintext(plaintext):
    raw = str(plaintext).encode("utf-8")
    length = len(raw)
    if length < 1 or length > MAX_PRIVATE_PLAINTEXT_BYTES:
        raise ValueError("private message size is outside the Friends NIP-44 resource limit")
    prefix = struct.pack(">H", length)
    return prefix + raw + (b"\x00" * (_calc_padded_len(length) - length))


def _unpad_plaintext(padded):
    if not isinstance(padded, (bytes, bytearray)) or len(padded) < 2:
        raise ValueError("invalid NIP-44 padding")
    length = struct.unpack(">H", bytes(padded[:2]))[0]
    if length < 1 or length > MAX_PRIVATE_PLAINTEXT_BYTES:
        raise ValueError("private message size is outside the Friends NIP-44 resource limit")
    if len(padded) != 2 + _calc_padded_len(length):
        raise ValueError("invalid NIP-44 padding size")
    raw = bytes(padded[2 : 2 + length])
    if len(raw) != length:
        raise ValueError("invalid NIP-44 plaintext length")
    return raw.decode("utf-8")


def _rotl32(value, shift):
    return ((value << shift) & 0xFFFFFFFF) | (value >> (32 - shift))


def _quarter_round(state, a, b, c, d):
    state[a] = (state[a] + state[b]) & 0xFFFFFFFF
    state[d] ^= state[a]
    state[d] = _rotl32(state[d], 16)
    state[c] = (state[c] + state[d]) & 0xFFFFFFFF
    state[b] ^= state[c]
    state[b] = _rotl32(state[b], 12)
    state[a] = (state[a] + state[b]) & 0xFFFFFFFF
    state[d] ^= state[a]
    state[d] = _rotl32(state[d], 8)
    state[c] = (state[c] + state[d]) & 0xFFFFFFFF
    state[b] ^= state[c]
    state[b] = _rotl32(state[b], 7)


def _chacha20_block(key, nonce, counter):
    if len(key) != 32 or len(nonce) != 12 or not 0 <= counter <= 0xFFFFFFFF:
        raise ValueError("invalid ChaCha20 parameters")
    constants = struct.unpack("<4I", b"expand 32-byte k")
    initial = list(constants + struct.unpack("<8I", key) + (counter,) + struct.unpack("<3I", nonce))
    working = initial[:]
    for _ in range(10):
        _quarter_round(working, 0, 4, 8, 12)
        _quarter_round(working, 1, 5, 9, 13)
        _quarter_round(working, 2, 6, 10, 14)
        _quarter_round(working, 3, 7, 11, 15)
        _quarter_round(working, 0, 5, 10, 15)
        _quarter_round(working, 1, 6, 11, 12)
        _quarter_round(working, 2, 7, 8, 13)
        _quarter_round(working, 3, 4, 9, 14)
    return struct.pack("<16I", *((working[i] + initial[i]) & 0xFFFFFFFF for i in range(16)))


def _chacha20_xor(key, nonce, data):
    raw = bytes(data)
    result = bytearray()
    for block_index in range((len(raw) + 63) // 64):
        stream = _chacha20_block(key, nonce, block_index)
        chunk = raw[block_index * 64 : (block_index + 1) * 64]
        result.extend(a ^ b for a, b in zip(chunk, stream))
    return bytes(result)


def _message_keys(conversation_key, nonce):
    if len(conversation_key) != 32 or len(nonce) != 32:
        raise ValueError("invalid NIP-44 key material")
    material = _hkdf_expand(conversation_key, nonce, 76)
    return material[:32], material[32:44], material[44:76]


def nip44_encrypt(secret_key, public_key, plaintext, nonce=None):
    """Encrypt a UTF-8 payload using NIP-44 v2."""
    nonce = secrets.token_bytes(32) if nonce is None else bytes(nonce)
    if len(nonce) != 32:
        raise ValueError("NIP-44 nonce must be 32 bytes")
    conversation_key = nip44_conversation_key(secret_key, public_key)
    chacha_key, chacha_nonce, hmac_key = _message_keys(conversation_key, nonce)
    ciphertext = _chacha20_xor(chacha_key, chacha_nonce, _pad_plaintext(plaintext))
    mac = hmac.new(hmac_key, nonce + ciphertext, hashlib.sha256).digest()
    return base64.b64encode(bytes((NIP44_VERSION,)) + nonce + ciphertext + mac).decode("ascii")


def nip44_decrypt(secret_key, public_key, payload):
    """Decrypt and authenticate a NIP-44 v2 payload."""
    if not isinstance(payload, str) or not payload or payload.startswith("#"):
        raise ValueError("unsupported NIP-44 payload")
    if len(payload) < 132 or len(payload) > MAX_PRIVATE_PAYLOAD_CHARS:
        raise ValueError("invalid NIP-44 payload size")
    try:
        decoded = base64.b64decode(payload, validate=True)
    except (ValueError, TypeError, base64.binascii.Error):
        raise ValueError("invalid NIP-44 base64")
    if len(decoded) < 99 or len(decoded) > MAX_PRIVATE_DECODED_BYTES:
        raise ValueError("invalid NIP-44 decoded payload size")
    if decoded[0] != NIP44_VERSION:
        raise ValueError("unsupported NIP-44 version")
    nonce = decoded[1:33]
    ciphertext = decoded[33:-32]
    supplied_mac = decoded[-32:]
    conversation_key = nip44_conversation_key(secret_key, public_key)
    chacha_key, chacha_nonce, hmac_key = _message_keys(conversation_key, nonce)
    calculated_mac = hmac.new(hmac_key, nonce + ciphertext, hashlib.sha256).digest()
    if not hmac.compare_digest(calculated_mac, supplied_mac):
        raise ValueError("NIP-44 message authentication failed")
    return _unpad_plaintext(_chacha20_xor(chacha_key, chacha_nonce, ciphertext))


def _legacy_shared_secret(secret_key, public_key):
    return hashlib.sha256(_shared_x(secret_key, public_key)).digest()


def encrypt_legacy_private_text(secret_key, public_key, plaintext):
    """Old Friends cipher, retained only so updated clients can reach old peers."""
    nonce = secrets.token_bytes(24)
    key = _legacy_shared_secret(secret_key, public_key)
    raw = str(plaintext).encode("utf-8")
    stream = b"".join(
        hashlib.sha256(key + nonce + index.to_bytes(4, "big")).digest()
        for index in range((len(raw) + 31) // 32)
    )
    ciphertext = bytes(a ^ b for a, b in zip(raw, stream))
    mac = hmac.new(key, nonce + ciphertext, hashlib.sha256).digest()
    return {
        "nonce": base64.b64encode(nonce).decode("ascii"),
        "ciphertext": base64.b64encode(ciphertext).decode("ascii"),
        "mac": mac.hex(),
    }


def _decrypt_legacy_private_text(secret_key, public_key, payload):
    key = _legacy_shared_secret(secret_key, public_key)
    try:
        nonce = base64.b64decode(payload["nonce"], validate=True)
        ciphertext = base64.b64decode(payload["ciphertext"], validate=True)
        mac = bytes.fromhex(payload["mac"])
    except (KeyError, TypeError, ValueError, base64.binascii.Error):
        raise ValueError("invalid legacy private payload")
    expected = hmac.new(key, nonce + ciphertext, hashlib.sha256).digest()
    if not hmac.compare_digest(mac, expected):
        raise ValueError("legacy message authentication failed")
    stream = b"".join(
        hashlib.sha256(key + nonce + index.to_bytes(4, "big")).digest()
        for index in range((len(ciphertext) + 31) // 32)
    )
    return bytes(a ^ b for a, b in zip(ciphertext, stream)).decode("utf-8")


def encrypt_private_text(secret_key, public_key, plaintext):
    """Friends compatibility API: all new payloads use NIP-44 v2."""
    return {
        "v": 2,
        "scheme": "nip44-v2",
        "payload": nip44_encrypt(secret_key, public_key, plaintext),
    }


def decrypt_private_text(secret_key, public_key, payload):
    """Read NIP-44 v2 plus pre-migration Friends payloads."""
    if isinstance(payload, str):
        return nip44_decrypt(secret_key, public_key, payload)
    if not isinstance(payload, dict):
        raise ValueError("invalid private payload")
    if payload.get("scheme") == "nip44-v2" or "payload" in payload:
        return nip44_decrypt(secret_key, public_key, payload.get("payload", ""))
    if {"nonce", "ciphertext", "mac"}.issubset(payload):
        return _decrypt_legacy_private_text(secret_key, public_key, payload)
    raise ValueError("unsupported private payload")


def _clean_tags(tags):
    result = []
    for tag in tags or []:
        if not isinstance(tag, (list, tuple)) or not tag:
            continue
        row = [str(value) for value in tag]
        if all(len(value) <= 8192 for value in row):
            result.append(row)
    return result[:64]


def _unsigned_event_id(pubkey, created_at, kind, tags, content):
    serialized = json.dumps(
        [0, pubkey, int(created_at), int(kind), _clean_tags(tags), str(content)],
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(serialized).hexdigest()


def _random_past_timestamp(now=None):
    now = int(time.time()) if now is None else int(now)
    return max(1, now - secrets.randbelow(NIP59_RANDOM_WINDOW_SECONDS + 1))


def create_nip17_rumor(sender_secret_key, receiver_public_keys, content, *, subject="", app_envelope=None, created_at=None):
    """Create one unsigned kind-14 rumor shared by all wrappers for a message."""
    sender = generate_keypair(sender_secret_key)["public_key"]
    receivers = []
    for value in receiver_public_keys or []:
        value = str(value).lower()
        _public_point(value)
        if value != sender and value not in receivers:
            receivers.append(value)
    if not receivers:
        raise ValueError("NIP-17 message needs at least one receiver")
    created_at = int(time.time()) if created_at is None else int(created_at)
    tags = [["p", value] for value in receivers]
    if subject:
        tags.append(["subject", str(subject)[:128]])
    tags.append(["client", "omarchy-friends"])
    if app_envelope is not None:
        envelope_json = json.dumps(app_envelope, ensure_ascii=False, separators=(",", ":"))
        if len(envelope_json.encode("utf-8")) > MAX_PRIVATE_PLAINTEXT_BYTES // 2:
            raise ValueError("private message envelope is too large")
        tags.append(["omarchy-envelope", envelope_json])
    plain = str(content) or "Shared an Omarchy Friends message"
    rumor = {
        "pubkey": sender,
        "created_at": created_at,
        "kind": NIP17_MESSAGE_KIND,
        "tags": _clean_tags(tags),
        "content": plain,
    }
    rumor["id"] = _unsigned_event_id(rumor["pubkey"], rumor["created_at"], rumor["kind"], rumor["tags"], rumor["content"])
    return rumor


def wrap_nip17_rumor(sender_secret_key, recipient_public_key, rumor):
    """Seal a rumor with the sender key, then gift-wrap it with a one-time key."""
    recipient_public_key = str(recipient_public_key).lower()
    _public_point(recipient_public_key)
    if not isinstance(rumor, dict) or rumor.get("kind") != NIP17_MESSAGE_KIND:
        raise ValueError("invalid NIP-17 rumor")
    sender_public_key = generate_keypair(sender_secret_key)["public_key"]
    if rumor.get("pubkey") != sender_public_key:
        raise ValueError("rumor sender does not match signing key")
    expected_id = _unsigned_event_id(rumor.get("pubkey", ""), rumor.get("created_at", 0), rumor.get("kind", -1), rumor.get("tags", []), rumor.get("content", ""))
    if rumor.get("id") != expected_id:
        raise ValueError("invalid rumor id")
    rumor_json = json.dumps(rumor, ensure_ascii=False, separators=(",", ":"))
    seal = build_event(sender_secret_key, NIP59_SEAL_KIND, [], nip44_encrypt(sender_secret_key, recipient_public_key, rumor_json), created_at=_random_past_timestamp())
    wrapper_identity = generate_keypair()
    wrapper_content = nip44_encrypt(wrapper_identity["secret_key"], recipient_public_key, json.dumps(seal, ensure_ascii=False, separators=(",", ":")))
    return build_event(wrapper_identity["secret_key"], NIP59_GIFT_WRAP_KIND, [["p", recipient_public_key]], wrapper_content, created_at=_random_past_timestamp())


def unwrap_nip17_gift_wrap(recipient_secret_key, event):
    """Validate and unwrap a NIP-59 gift wrap into a NIP-17 kind-14 rumor."""
    if not verify_event(event) or int(event.get("kind", -1)) != NIP59_GIFT_WRAP_KIND:
        raise ValueError("invalid NIP-59 gift wrap")
    recipient_public_key = generate_keypair(recipient_secret_key)["public_key"]
    p_values = [tag[1] for tag in event.get("tags", []) if isinstance(tag, list) and len(tag) >= 2 and tag[0] == "p" and isinstance(tag[1], str)]
    if recipient_public_key not in p_values:
        raise ValueError("gift wrap is for another recipient")
    seal = json.loads(nip44_decrypt(recipient_secret_key, event.get("pubkey", ""), event.get("content", "")))
    if not isinstance(seal, dict) or int(seal.get("kind", -1)) != NIP59_SEAL_KIND:
        raise ValueError("invalid NIP-59 seal")
    if seal.get("tags") != [] or not verify_event(seal):
        raise ValueError("invalid NIP-59 seal signature")
    rumor = json.loads(nip44_decrypt(recipient_secret_key, seal.get("pubkey", ""), seal.get("content", "")))
    if not isinstance(rumor, dict) or rumor.get("sig") is not None:
        raise ValueError("invalid NIP-17 rumor")
    if int(rumor.get("kind", -1)) != NIP17_MESSAGE_KIND:
        raise ValueError("unsupported NIP-17 rumor kind")
    if rumor.get("pubkey") != seal.get("pubkey"):
        raise ValueError("NIP-17 sender mismatch")
    expected_id = _unsigned_event_id(rumor.get("pubkey", ""), rumor.get("created_at", 0), rumor.get("kind", -1), rumor.get("tags", []), rumor.get("content", ""))
    if rumor.get("id") != expected_id:
        raise ValueError("invalid NIP-17 rumor id")
    return rumor


def app_envelope_from_rumor(rumor):
    """Return the private Omarchy envelope tag, if present."""
    for tag in rumor.get("tags", []) if isinstance(rumor, dict) else []:
        if isinstance(tag, list) and len(tag) >= 2 and tag[0] == "omarchy-envelope":
            try:
                value = json.loads(tag[1])
            except (TypeError, ValueError):
                return None
            return value if isinstance(value, dict) else None
    return None
