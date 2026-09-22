# Private messaging security migration — v4.15 implementation record

The migration from the historical Friends private-message construction to a standardized Nostr private-message stack is implemented on `feature/build-network` for v4.15.

This document records what changed, what compatibility remains, and what still requires real-system validation. It is **not** a claim that the Omarchy Friends implementation has received an independent security audit.

## Current-to-current transport

When both Friends peers advertise the v4.15 private-message capabilities, private messages use:

- **NIP-44 v2** authenticated encryption;
- **NIP-17 kind-14 rumors** as the private-message structure;
- **NIP-59 kind-13 seals and kind-1059 gift wraps** for relay-facing metadata protection;
- **NIP-17 kind-10050 DM inbox relay lists** to select the recipient's private-message relays.

Implementation: `bin/omarchy_friends_private.py` plus the transport/state integration in `bin/omarchy-friends`.

For direct messages, the relay-facing gift wrap is signed by a one-time wrapper key and carries the recipient `p` tag. The true sender and plaintext exist only inside the encrypted seal/rumor. The receiver additionally rejects a valid outer gift wrap when the decrypted kind-14 rumor does not actually address that receiver.

For small Friends groups, one shared NIP-17 rumor is individually gift-wrapped for each current recipient. Group id, group name and the other group members stay inside the encrypted rumor rather than in the public outer event.

## DM inbox relay routing

Each current Friends client publishes a signed kind-10050 inbox-relay event and listens on its configured inbox relays. A sender fetches the recipient's newest verified kind-10050 event and sends the kind-1059 gift wrap only to the selected recipient inbox relays.

Friends deliberately applies an extra outbound-network safety boundary: a relay advertised by another user is followed only when that relay is already present in the local `OMARCHY_FRIENDS_RELAYS` / `GLOBAL_RELAYS` configuration. The cached list is bounded to three relays. This prevents an untrusted remote relay-list event from turning Friends into arbitrary WebSocket egress.

That means v4.15 interoperability currently requires overlap between the two users' configured relay sets. Real-system validation must prove that the chosen public relays accept kind-10050 and kind-1059 events. If a relay requires authentication such as NIP-42, record that exact real-relay failure rather than adding speculative authentication code.

## Upgrade compatibility and downgrade resistance

The old format is retained only as a transition path:

- v4.15 can **read** historical Friends `{nonce,ciphertext,mac}` payloads;
- a friend that has never advertised the complete modern capability set can still receive the historical tagged kind-4 Friends DM/group envelope;
- once a friendship has advertised the modern protocol, that upgrade marker is persisted in local state so stale/expired World presence does not silently downgrade the friendship after restart;
- a modern send still requires a usable verified/cached recipient inbox relay list. Failure to obtain one fails the modern send instead of silently changing cryptographic transport.

This keeps one-sided upgrades workable without treating temporary presence loss as permission to downgrade an already-modern friendship.

## NIP-44 resource bound

NIP-44 v2 itself supports an extended length format. Friends intentionally applies a much smaller **65,535-byte plaintext resource cap** plus a bounded encoded-payload size. This is an application-level memory/DoS limit, not the NIP-44 protocol maximum.

Normal Friends chat text and media-link envelopes are already far below this bound.

## Implemented validation

CI covers:

1. the official NIP-44 v2 conversation-key/ciphertext reference vector;
2. NIP-44 round-trip encryption and MAC/ciphertext tamper rejection;
3. the Friends plaintext/payload resource bounds;
4. legacy read compatibility plus confirmation that the new compatibility API writes NIP-44 v2;
5. NIP-17/NIP-59 gift-wrap round-trip;
6. wrong-recipient gift-wrap rejection;
7. rejection when the decrypted kind-14 rumor does not address the receiver;
8. group metadata absence from the public outer gift wrap;
9. signed kind-10050 parsing, author/signature checks, bounded relay selection and rejection of unconfigured remote relay URLs;
10. actual `FriendsEngine.send_dm()` choosing kind-1059 for a capable peer, routing through the recipient inbox list and decrypting at the receiver;
11. persisted modern-protocol/inbox state surviving restart;
12. actual FriendsEngine fallback to historical kind-4 for a peer that has never advertised the modern capabilities;
13. actual group-invite gift wrapping keeping the sender/group/member graph out of the outer event;
14. the complete existing Friends/Build Network unit suite and two-user simulated relay journey.

The release gate also compiles `bin/omarchy_friends_private.py` and the live Friends engine.

## Real-system gates still required

Before calling v4.15 stable:

- run two isolated current Friends installations through real configured relays;
- verify both clients publish/fetch signed kind-10050 inbox lists;
- verify direct and group kind-1059 events are written only to the advertised configured inbox relays and are received there;
- inspect captured outer gift wraps for plaintext, real-sender and group-graph leakage;
- restart both sides and confirm the modern anti-downgrade/inbox state survives;
- verify no duplicate local message when a best-effort sender copy returns;
- run the documented v4.15-to-pre-v4.15 compatibility test;
- run the normal Friends regression suite on the actual Omarchy shell.

See `CODEX_REAL_SYSTEM_TEST.md` for the exact procedure.

These are deliberately real-environment validation gates. A failing gate may justify a small targeted fix; a passing gate is not an invitation to add another crypto layer, transport architecture or social feature. This implementation record is frozen for v4.15 unless one of those real tests demonstrates a factual mismatch.

## Security limitations / wording

Do not say “Omarchy Friends is audited” or imply that this Python implementation itself has been independently reviewed. Standardized protocol selection and reference-vector conformance are materially better than an ad-hoc construction, but they are not a substitute for an implementation audit.

NIP-44 does not provide forward secrecy or post-compromise security. Friends should therefore not be positioned as a high-assurance messenger for highly sensitive secrets.

## Removal of the legacy path

Do **not** delete legacy read/send fallback as part of v4.15 cleanup. Remove it only in a future release after there is an explicit transition decision and evidence that the compatibility window can close without stranding active users.