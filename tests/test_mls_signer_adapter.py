import json
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace


BIN_DIR = Path(__file__).parent.parent / "bin"
sys.path.insert(0, str(BIN_DIR))

from omarchy_friends_global import build_event, generate_keypair, verify_event
from omarchy_friends_private import nip44_decrypt, nip44_encrypt
from omarchy_friends_mls import make_external_account_signer


class MlsSignerAdapterTests(unittest.TestCase):
    def setUp(self):
        self.alice = generate_keypair(1)
        self.bob = generate_keypair(2)
        self.bindings = SimpleNamespace(ExternalAccountSignerFfi=type("ForeignSigner", (), {}))
        self.signer = make_external_account_signer(
            self.bindings, self.alice, build_event, verify_event, nip44_encrypt, nip44_decrypt
        )

    def test_signs_mdk_unsigned_event_with_existing_friends_identity(self):
        request = {
            "id": None,
            "pubkey": self.alice["public_key"],
            "created_at": 123456,
            "kind": 445,
            "tags": [["h", "group-id"], ["p", self.bob["public_key"]]],
            "content": "opaque MLS ciphertext",
        }

        signed = json.loads(self.signer.sign_event(json.dumps(request)))

        self.assertEqual(signed["pubkey"], self.alice["public_key"])
        self.assertEqual(signed["kind"], 445)
        self.assertTrue(verify_event(signed))

    def test_rejects_foreign_identity_malformed_tags_and_changed_event_id(self):
        request = {
            "pubkey": self.bob["public_key"], "created_at": 1, "kind": 445,
            "tags": [], "content": "ciphertext",
        }
        with self.assertRaises(ValueError):
            self.signer.sign_event(json.dumps(request))

        request["pubkey"] = self.alice["public_key"]
        request["tags"] = [["p", None]]
        with self.assertRaises(ValueError):
            self.signer.sign_event(json.dumps(request))

        request["tags"] = []
        request["id"] = "0" * 64
        with self.assertRaises(ValueError):
            self.signer.sign_event(json.dumps(request))

    def test_reuses_friends_nip44_callback_and_fails_closed_for_nip04(self):
        payload = self.signer.nip44_encrypt(self.bob["public_key"], "secret probe")
        self.assertEqual(
            nip44_decrypt(self.bob["secret_key"], self.alice["public_key"], payload),
            "secret probe",
        )
        with self.assertRaisesRegex(RuntimeError, "does not support NIP-04"):
            self.signer.nip04_encrypt(self.bob["public_key"], "unused")

    def test_rejects_identity_pair_mismatch_before_creating_callback(self):
        mismatched = dict(self.alice, public_key=self.bob["public_key"])
        with self.assertRaisesRegex(ValueError, "does not match"):
            make_external_account_signer(
                self.bindings, mismatched, build_event, verify_event, nip44_encrypt, nip44_decrypt
            )


if __name__ == "__main__":
    unittest.main()
