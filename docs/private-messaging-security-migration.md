# Private messaging security migration gate

Omarchy Friends currently has a working private-message path. The Build Network branch intentionally does **not** silently replace that cryptography while simultaneously changing the product surface.

## Goal

Move private DMs/groups toward a standard, well-reviewed Nostr-compatible private-message design rather than maintaining a custom encryption construction.

Candidates to evaluate:

- NIP-44 v2 for private-message encryption;
- NIP-17 for private direct-message structure;
- NIP-59 gift wrapping for stronger metadata privacy where interoperable.

## Why this is a separate migration

A cryptographic migration must preserve all of these at once:

- existing users must not lose access to current conversations;
- old/new clients need a defined compatibility period;
- no downgrade ambiguity;
- malformed ciphertext must fail closed;
- relays must never learn plaintext;
- groups need an explicit design rather than assuming a DM primitive automatically makes group messaging safe;
- migration must be validated between two real independent installations.

Changing crypto casually during a large UI/collaboration release would increase risk, not reduce it.

## Required implementation gates

1. Write protocol-versioned fixtures for current encrypted DMs.
2. Add NIP-44 reference vectors from the authoritative specification/test vectors.
3. Implement the standard algorithm exactly; do not invent another construction.
4. Add cross-client encrypt/decrypt tests.
5. Define dual-read behavior during migration.
6. Decide whether dual-write is required and bound the transition period.
7. Test corrupted MAC/ciphertext, replay, wrong-key and malformed-envelope cases.
8. Test relay metadata exposure.
9. Define group-message migration separately.
10. Run two-machine interoperability before changing the default capability advertised by Friends.

## Marketing rule

Until this migration/audit is complete, describe private messages conservatively and do not imply a security audit that has not happened.

## Non-goal

This document is not permission for an agent to “improve” crypto by replacing primitives from memory. The migration should be driven by the current Nostr specifications and their official test vectors at implementation time.
