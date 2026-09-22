#!/usr/bin/env python3
"""One-shot v4.15 standards hardening.

Tightens NIP-44 limits to the upstream v2 spec and makes a successfully
observed modern private-message capability sticky per friendship so an expired
World-presence cache cannot silently downgrade that friend to legacy crypto.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new, label):
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_private_module():
    replace_once(
        "bin/omarchy_friends_private.py",
        "MAX_PRIVATE_PLAINTEXT_BYTES = 64 * 1024\nMAX_PRIVATE_PAYLOAD_CHARS = 128 * 1024\n",
        "MAX_PRIVATE_PLAINTEXT_BYTES = 65535\nMAX_PRIVATE_PAYLOAD_CHARS = 87472\nMAX_PRIVATE_DECODED_BYTES = 65603\n",
        "NIP-44 byte limits",
    )
    replace_once(
        "bin/omarchy_friends_private.py",
        '''    if length < 1 or length > MAX_PRIVATE_PLAINTEXT_BYTES:\n        raise ValueError("private message size is outside Friends limits")\n    if length < 65536:\n        prefix = struct.pack(">H", length)\n    else:\n        prefix = b"\\x00\\x00" + struct.pack(">I", length)\n    return prefix + raw + (b"\\x00" * (_calc_padded_len(length) - length))\n''',
        '''    if length < 1 or length > MAX_PRIVATE_PLAINTEXT_BYTES:\n        raise ValueError("private message size is outside NIP-44 v2 limits")\n    prefix = struct.pack(">H", length)\n    return prefix + raw + (b"\\x00" * (_calc_padded_len(length) - length))\n''',
        "NIP-44 16-bit padding prefix",
    )
    replace_once(
        "bin/omarchy_friends_private.py",
        '''    first = struct.unpack(">H", bytes(padded[:2]))[0]\n    if first == 0:\n        if len(padded) < 6:\n            raise ValueError("invalid NIP-44 padding")\n        length = struct.unpack(">I", bytes(padded[2:6]))[0]\n        if length < 65536:\n            raise ValueError("invalid NIP-44 extended length")\n        prefix_len = 6\n    else:\n        length = first\n        prefix_len = 2\n    if length < 1 or length > MAX_PRIVATE_PLAINTEXT_BYTES:\n        raise ValueError("private message size is outside Friends limits")\n    if len(padded) != prefix_len + _calc_padded_len(length):\n        raise ValueError("invalid NIP-44 padding size")\n    raw = bytes(padded[prefix_len : prefix_len + length])\n''',
        '''    length = struct.unpack(">H", bytes(padded[:2]))[0]\n    if length < 1 or length > MAX_PRIVATE_PLAINTEXT_BYTES:\n        raise ValueError("private message size is outside NIP-44 v2 limits")\n    if len(padded) != 2 + _calc_padded_len(length):\n        raise ValueError("invalid NIP-44 padding size")\n    raw = bytes(padded[2 : 2 + length])\n''',
        "NIP-44 unpadding",
    )
    replace_once(
        "bin/omarchy_friends_private.py",
        '''    if len(decoded) < 99 or decoded[0] != NIP44_VERSION:\n        raise ValueError("unsupported NIP-44 version")\n''',
        '''    if len(decoded) < 99 or len(decoded) > MAX_PRIVATE_DECODED_BYTES:\n        raise ValueError("invalid NIP-44 decoded payload size")\n    if decoded[0] != NIP44_VERSION:\n        raise ValueError("unsupported NIP-44 version")\n''',
        "NIP-44 decoded size bound",
    )


def patch_engine_sticky_capability():
    replace_once(
        "bin/omarchy-friends",
        '''    def _supports_nip17(self, public_key):\n        public_key = trim_text(public_key, 64).lower()\n        peer = self.state.get("global", {}).get("peers", {}).get(public_key, {})\n        capabilities = set(peer.get("capabilities", [])) if isinstance(peer, dict) else set()\n        return {"nip44-v2", "nip17-dm-v1"}.issubset(capabilities)\n''',
        '''    def _supports_nip17(self, public_key):\n        public_key = trim_text(public_key, 64).lower()\n        global_state = self.state.setdefault("global", {})\n        friendship = global_state.setdefault("friendships", {}).get(public_key, {})\n        if isinstance(friendship, dict) and friendship.get("private_protocol") == "nip17-v1":\n            return True\n        peer = global_state.get("peers", {}).get(public_key, {})\n        capabilities = set(peer.get("capabilities", [])) if isinstance(peer, dict) else set()\n        modern = {"nip44-v2", "nip17-dm-v1"}.issubset(capabilities)\n        if modern and isinstance(friendship, dict) and friendship.get("status") == "friends":\n            # Security upgrade is sticky: once a friend has advertised the\n            # modern protocol, a later absence/stale presence must not silently\n            # downgrade that established friendship to the legacy transport.\n            friendship["private_protocol"] = "nip17-v1"\n            friendship["private_protocol_seen_at"] = now_seconds()\n        return modern\n''',
        "sticky private protocol capability",
    )


def patch_tests():
    replace_once(
        "tests/test_private_messaging.py",
        '''    def test_nip17_gift_wrap_roundtrip(self):\n''',
        '''    def test_nip44_v2_exact_size_boundaries(self):\n        self.assertEqual(private.MAX_PRIVATE_PLAINTEXT_BYTES, 65535)\n        self.assertEqual(private.MAX_PRIVATE_PAYLOAD_CHARS, 87472)\n        padded = private._pad_plaintext("a" * 65535)\n        self.assertEqual(len(padded), 2 + private._calc_padded_len(65535))\n        self.assertEqual(private._unpad_plaintext(padded), "a" * 65535)\n        with self.assertRaises(ValueError):\n            private._pad_plaintext("a" * 65536)\n        with self.assertRaises(ValueError):\n            private._pad_plaintext("")\n        alice = generate_keypair()\n        bob = generate_keypair()\n        with self.assertRaises(ValueError):\n            private.nip44_decrypt(\n                alice["secret_key"], bob["public_key"], "A" * 87473\n            )\n\n    def test_nip17_gift_wrap_roundtrip(self):\n''',
        "NIP-44 boundary tests",
    )
    replace_once(
        "tests/test_private_messaging_engine.py",
        '''    def test_old_peer_still_uses_legacy_transport_during_upgrade_window(self):\n''',
        '''    def test_modern_capability_is_sticky_after_presence_expires(self):\n        self.make_friends(self.alice, self.bob)\n        self.advertise_modern(self.alice, self.bob)\n        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))\n        friend = self.alice.state["global"]["friendships"][self.key(self.bob)]\n        self.assertEqual(friend.get("private_protocol"), "nip17-v1")\n        self.alice.state["global"]["peers"].pop(self.key(self.bob), None)\n        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))\n\n    def test_old_peer_still_uses_legacy_transport_during_upgrade_window(self):\n''',
        "sticky capability engine test",
    )


def main():
    patch_private_module()
    patch_engine_sticky_capability()
    patch_tests()
    print("v4.15 private messaging standards hardening applied")


if __name__ == "__main__":
    main()
