import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

BIN_DIR = Path(__file__).parent.parent / "bin"
sys.path.insert(0, str(BIN_DIR))

import omarchy_friends_private as private  # noqa: E402
from omarchy_friends_global import generate_keypair  # noqa: E402


class TestPrivateMessagingStandards(unittest.TestCase):
    def test_nip44_official_vector(self):
        sec1 = "0" * 63 + "1"
        sec2 = "0" * 63 + "2"
        pub2 = generate_keypair(sec2)["public_key"]
        self.assertEqual(
            private.nip44_conversation_key(sec1, pub2).hex(),
            "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
        )
        nonce = bytes.fromhex("00" * 31 + "01")
        payload = private.nip44_encrypt(sec1, pub2, "a", nonce=nonce)
        self.assertEqual(
            payload,
            "AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEAjD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb",
        )
        pub1 = generate_keypair(sec1)["public_key"]
        self.assertEqual(private.nip44_decrypt(sec2, pub1, payload), "a")

    def test_nip44_roundtrip_and_tamper_rejection(self):
        alice = generate_keypair()
        bob = generate_keypair()
        payload = private.nip44_encrypt(alice["secret_key"], bob["public_key"], "hello 🔐")
        self.assertEqual(private.nip44_decrypt(bob["secret_key"], alice["public_key"], payload), "hello 🔐")
        raw = bytearray(__import__("base64").b64decode(payload))
        raw[-1] ^= 1
        tampered = __import__("base64").b64encode(raw).decode()
        with self.assertRaises(ValueError):
            private.nip44_decrypt(bob["secret_key"], alice["public_key"], tampered)

    def test_legacy_payload_is_readable_but_new_payload_is_nip44(self):
        alice = generate_keypair()
        bob = generate_keypair()
        legacy = private.encrypt_legacy_private_text(alice["secret_key"], bob["public_key"], "old message")
        self.assertEqual(private.decrypt_private_text(bob["secret_key"], alice["public_key"], legacy), "old message")
        modern = private.encrypt_private_text(alice["secret_key"], bob["public_key"], "new message")
        self.assertEqual(modern["scheme"], "nip44-v2")
        self.assertEqual(private.decrypt_private_text(bob["secret_key"], alice["public_key"], modern), "new message")

    def test_nip17_gift_wrap_roundtrip(self):
        alice = generate_keypair()
        bob = generate_keypair()
        envelope = {"v": 3, "type": "direct", "text": "hello", "media": []}
        rumor = private.create_nip17_rumor(
            alice["secret_key"], [bob["public_key"]], "hello", app_envelope=envelope, created_at=1_700_000_000
        )
        with patch.object(private, "_random_past_timestamp", return_value=1_699_900_000):
            gift = private.wrap_nip17_rumor(alice["secret_key"], bob["public_key"], rumor)
        opened = private.unwrap_nip17_gift_wrap(bob["secret_key"], gift)
        self.assertEqual(opened["id"], rumor["id"])
        self.assertEqual(opened["pubkey"], alice["public_key"])
        self.assertEqual(opened["content"], "hello")
        self.assertEqual(private.app_envelope_from_rumor(opened), envelope)
        self.assertEqual(gift["kind"], private.NIP59_GIFT_WRAP_KIND)
        self.assertNotEqual(gift["pubkey"], alice["public_key"])

    def test_gift_wrap_for_other_recipient_is_rejected(self):
        alice = generate_keypair()
        bob = generate_keypair()
        carol = generate_keypair()
        rumor = private.create_nip17_rumor(alice["secret_key"], [bob["public_key"]], "private")
        gift = private.wrap_nip17_rumor(alice["secret_key"], bob["public_key"], rumor)
        with self.assertRaises(ValueError):
            private.unwrap_nip17_gift_wrap(carol["secret_key"], gift)

    def test_group_rumor_hides_members_inside_gift_wrap(self):
        alice = generate_keypair()
        bob = generate_keypair()
        carol = generate_keypair()
        envelope = {"v": 3, "type": "group_message", "group_id": "abc123", "text": "ship it", "media": []}
        rumor = private.create_nip17_rumor(
            alice["secret_key"],
            [bob["public_key"], carol["public_key"]],
            "ship it",
            subject="Ship Crew",
            app_envelope=envelope,
        )
        gift = private.wrap_nip17_rumor(alice["secret_key"], bob["public_key"], rumor)
        public_text = json.dumps(gift, sort_keys=True)
        self.assertNotIn("abc123", public_text)
        self.assertNotIn("Ship Crew", public_text)
        self.assertNotIn(alice["public_key"], public_text)
        self.assertNotIn(carol["public_key"], public_text)
        opened = private.unwrap_nip17_gift_wrap(bob["secret_key"], gift)
        self.assertEqual(private.app_envelope_from_rumor(opened)["group_id"], "abc123")


if __name__ == "__main__":
    unittest.main()
