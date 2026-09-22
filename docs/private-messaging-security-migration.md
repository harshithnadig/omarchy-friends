# Private messaging security migration — v4.15 implementation record

The migration from the historical Friends private-message construction to a standardized Nostr private-message stack is implemented on `feature/build-network` for v4.15.

This document records what changed, what compatibility remains, and what still requires real-system validation. It is **not** a claim that the Omarchy Friends implementation has received an independent security audit.

## Current-to-current transport

When both Friends peers advertise the v4.15 private-message capabilities, private messages use:

- **NIP-44 v2** authenticated encryption;
- **NIP-17 kind-14 rumors** as the private-message structure;
- **NIP-59 kind-13 seals and kind-1059 gift wraps** for relay-facing metadata protection.

Implementation: `bin/omarchy_friends_private.py`.

For direct messages, the relay-facing gift wrap is signed by a one-time wrapper key and carries the recipient `p` tag. The true sender and plaintext exist only inside the encrypted seal/rumor.

For small Friends groups, one shared NIP-17 rumor is individually gift-wrapped for each current recipient. Group id, group name and the other group members stay inside the encrypted rumor rather than in the public outer event.

Friends continues to use its configured relay set for delivery. This migration does not claim generic cross-client Nostr messenger interoperability or recipient relay-list discovery.

## Upgrade compatibility

The old format is retained only as a transition path:

- v4.15 can **read** historical Friends `{nonce,ciphertext,mac}` payloads;
- if a friend's current World presence does not advertise `nip44-v2` + `nip17-dm-v1`, v4.15 sends that friend the historical tagged kind-4 Friends DM/group envelope;
- when the peer advertises the modern capabilities, v4.15 prefers NIP-17/NIP-59 and does not choose the legacy path merely because it still exists.

This prevents one-sided upgrades from breaking established friendships/groups.

## Implemented validation

CI covers:

1. the official NIP-44 v2 conversation-key/ciphertext reference vector;
2. NIP-44 round-trip encryption and MAC/ciphertext tamper rejection;
3. legacy read compatibility plus confirmation that the new compatibility API writes NIP-44 v2;
4. NIP-17/NIP-59 gift-wrap round-trip;
5. wrong-recipient gift-wrap rejection;
6. group metadata absence from the public outer gift wrap;
7. actual `FriendsEngine.send_dm()` choosing kind-1059 for a capable peer and decrypting at the receiver;
8. actual FriendsEngine fallback to historical kind-4 for a peer without modern capabilities;
9. actual group-invite gift wrapping keeping the sender/group/member graph out of the outer event;
10. the complete existing Friends/Build Network unit suite and two-user simulated relay journey.

The release gate also compiles `bin/omarchy_friends_private.py` and the live Friends engine.

## Real-system gates still required

Before calling v4.15 stable:

- run two isolated current Friends installations through real configured relays;
- verify direct and group kind-1059 delivery;
- inspect captured outer gift wraps for metadata exposure;
- verify no duplicate local message when a best-effort sender copy returns;
- run the documented v4.15-to-legacy compatibility test;
- run the normal Friends regression suite on the actual Omarchy shell.

See `CODEX_REAL_SYSTEM_TEST.md` for the exact procedure.

## Security limitations / wording

Do not say “Omarchy Friends is audited” or imply that this Python implementation itself has been independently reviewed. Standardized protocol selection and reference-vector conformance are materially better than an ad-hoc construction, but they are not a substitute for an implementation audit.

NIP-44 does not provide forward secrecy or post-compromise security. Friends should therefore not be positioned as a high-assurance messenger for highly sensitive secrets.

## Removal of the legacy path

Do **not** delete legacy read/send fallback as part of v4.15 cleanup. Remove it only in a future release after there is an explicit transition decision and evidence that the compatibility window can close without stranding active users.
