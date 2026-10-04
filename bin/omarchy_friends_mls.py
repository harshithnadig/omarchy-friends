"""Narrow MDK signer adapter that keeps Friends' Nostr key in Python.

This module does not start the MDK runtime or switch message transports. The
native engine calls back into the existing account signer for signatures and
NIP-44, so the account secret never crosses the UniFFI boundary.
"""

from __future__ import annotations

import json


MAX_UNSIGNED_EVENT_BYTES = 2 * 1024 * 1024
MAX_EVENT_TAGS = 64  # Matches Friends' existing Nostr event signing contract.
MAX_TAG_VALUE_CHARS = 8192


def make_external_account_signer(bindings, identity, build_event, verify_event, nip44_encrypt, nip44_decrypt):
    """Create MDK's callback implementation around an existing Friends identity.

    `bindings` is the generated UniFFI Python module. Crypto functions are
    injected so this module stays importable and testable without the optional
    native bridge installed.
    """
    if not isinstance(identity, dict):
        raise ValueError("Friends identity is unavailable")
    secret_key = identity.get("secret_key")
    public_key = identity.get("public_key")
    if not isinstance(secret_key, str) or len(secret_key) != 64:
        raise ValueError("Friends identity secret is invalid")
    if not isinstance(public_key, str) or len(public_key) != 64:
        raise ValueError("Friends identity public key is invalid")
    identity_probe = build_event(secret_key, 0, [], "", created_at=0)
    if identity_probe.get("pubkey") != public_key or not verify_event(identity_probe):
        raise ValueError("Friends identity secret does not match its public key")

    base = getattr(bindings, "ExternalAccountSignerFfi", None)
    if base is None:
        raise RuntimeError("The installed MLS bridge has no external-signer interface")

    class FriendsExternalAccountSigner(base):
        def public_key(self):
            return public_key

        def sign_event(self, unsigned_event_json):
            if not isinstance(unsigned_event_json, str) or len(unsigned_event_json.encode("utf-8")) > MAX_UNSIGNED_EVENT_BYTES:
                raise ValueError("MDK requested an oversized Nostr event")
            request = json.loads(unsigned_event_json)
            if not isinstance(request, dict) or request.get("pubkey") != public_key:
                raise ValueError("MDK requested a signature for a different account")
            created_at = request.get("created_at")
            kind = request.get("kind")
            tags = request.get("tags")
            content = request.get("content")
            if (type(created_at) is not int or created_at < 0
                    or type(kind) is not int or kind < 0
                    or not isinstance(tags, list) or len(tags) > MAX_EVENT_TAGS
                    or not isinstance(content, str)):
                raise ValueError("MDK requested a malformed Nostr event")
            for tag in tags:
                if (not isinstance(tag, list) or not tag
                        or any(not isinstance(value, str) or len(value) > MAX_TAG_VALUE_CHARS for value in tag)):
                    raise ValueError("MDK requested malformed Nostr event tags")

            event = build_event(secret_key, kind, tags, content, created_at=created_at)
            expected_id = request.get("id")
            if expected_id is not None and expected_id != event.get("id"):
                raise ValueError("MDK event id does not match the Friends signature")
            if event.get("pubkey") != public_key or not verify_event(event):
                raise ValueError("Friends could not verify the signed MDK event")
            return json.dumps(event, ensure_ascii=False, separators=(",", ":"))

        def nip04_encrypt(self, public_key, content):
            raise RuntimeError("Friends does not support NIP-04 in MLS signer callbacks")

        def nip04_decrypt(self, public_key, encrypted_content):
            raise RuntimeError("Friends does not support NIP-04 in MLS signer callbacks")

        def nip44_encrypt(self, public_key, content):
            return nip44_encrypt(secret_key, public_key, content)

        def nip44_decrypt(self, public_key, payload):
            return nip44_decrypt(secret_key, public_key, payload)

    return FriendsExternalAccountSigner()
