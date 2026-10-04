#!/usr/bin/env python3
"""Exercise the generated MDK bridge with temporary Friends identities/local relay."""

from __future__ import annotations

import asyncio
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "bin"))
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(Path(sys.argv[1]).resolve()))

import marmot_uniffi  # noqa: E402
from omarchy_friends_global import build_event, generate_keypair, verify_event  # noqa: E402
from omarchy_friends_mls import make_external_account_signer  # noqa: E402
from omarchy_friends_private import nip44_decrypt, nip44_encrypt  # noqa: E402
from test_private_messaging_engine import LoopbackNostrRelay  # noqa: E402


class TemporarySecretStore(marmot_uniffi.SecretStore):
    """In-memory only; MLS smoke identities and credentials are disposable."""

    def __init__(self):
        self.values = {}

    def has_secret_for_label(self, label):
        return label in self.values

    def has_secret_for_account_id(self, account_id_hex):
        return False

    def write_secret(self, label, account_id_hex, secret_key_hex):
        self.values[label] = secret_key_hex

    def load_secret(self, label, account_id_hex):
        return self.values[label]

    def remove_secret(self, label, account_id_hex):
        self.values.pop(label, None)


def signer_for(identity):
    return make_external_account_signer(
        marmot_uniffi,
        identity,
        build_event,
        verify_event,
        nip44_encrypt,
        nip44_decrypt,
    )


async def main():
    with tempfile.TemporaryDirectory(prefix="omarchy-friends-mls-bridge-smoke-") as temp:
        root = Path(temp)
        alice_identity = generate_keypair()
        bob_identity = generate_keypair()
        with LoopbackNostrRelay() as relay:
            relays = [relay.url]
            alice = marmot_uniffi.Marmot.new_with_options(
                str(root / "alice"),
                relays,
                marmot_uniffi.RelayPolicyFfi.ALLOW_LOOPBACK,
                TemporarySecretStore(),
            )
            bob = marmot_uniffi.Marmot.new_with_options(
                str(root / "bob"),
                relays,
                marmot_uniffi.RelayPolicyFfi.ALLOW_LOOPBACK,
                TemporarySecretStore(),
            )
            try:
                await alice.start()
                await bob.start()
                alice_account = await alice.login_external_signer(
                    alice_identity["public_key"], signer_for(alice_identity), relays, relays
                )
                bob_account = await bob.login_external_signer(
                    bob_identity["public_key"], signer_for(bob_identity), relays, relays
                )
                if not alice_account.external_signing or not bob_account.external_signing:
                    raise RuntimeError("MDK did not retain external-signer mode")

                group_id = await alice.create_group(
                    alice_account.account_id_hex,
                    "Friends isolated bridge smoke",
                    [bob_account.account_id_hex],
                    None,
                )
                invite_deadline = time.monotonic() + 20
                while True:
                    try:
                        await bob.accept_group_invite(bob_account.account_id_hex, group_id)
                        break
                    except marmot_uniffi.MarmotKitError as error:
                        if time.monotonic() >= invite_deadline:
                            raise RuntimeError("Bob did not accept the localhost MLS Welcome") from error
                        await asyncio.sleep(0.1)

                sent = await alice.send_text(
                    alice_account.account_id_hex, group_id, "Python FFI MLS message"
                )
                if sent.published <= 0:
                    raise RuntimeError("Alice's MLS event was not published to the local relay")

                query = marmot_uniffi.TimelineMessageQueryFfi(
                    group_id_hex=group_id,
                    search=None,
                    before=None,
                    before_message_id=None,
                    after=None,
                    after_message_id=None,
                    limit=20,
                )
                message_deadline = time.monotonic() + 20
                while time.monotonic() < message_deadline:
                    page = bob.timeline_messages(bob_account.account_id_hex, query)
                    if any(message.plaintext == "Python FFI MLS message" for message in page.messages):
                        print("PASS two-client MLS Welcome, external signing, and message over localhost relay")
                        return
                    await asyncio.sleep(0.1)
                raise RuntimeError("Bob did not receive and decrypt Alice's MLS message")
            finally:
                await alice.shutdown_and_close()
                await bob.shutdown_and_close()


if __name__ == "__main__":
    asyncio.run(main())
