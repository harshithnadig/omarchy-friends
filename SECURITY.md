# Security policy

Omarchy Friends is a third-party Omarchy plugin. Omarchy plugins run inside the user's shell context and are not sandboxed, so security bugs in plugin code can affect the local desktop session.

## Local encrypted state

Friends encrypts its local profile and message journal with AES-GCM. Per-conversation preview summaries are encrypted separately; their SQLite lookup tokens are keyed HMACs of the conversation identifier, so the database does not expose peer IDs or message text. A reader of the database can still observe the number of conversations and that a token recurs for the same conversation. Full message payloads remain encrypted. On the normal XDG state directory, Friends stores the state key in the desktop Secret Service via `secret-tool`, verifies the stored value before replacing the legacy key file, and leaves a non-secret marker at the old key path. Existing local key files migrate without re-encrypting or rewriting the user's history. Isolated/non-default state directories used by tests retain their local key files. If Secret Service cannot store a new key, Friends retains the mode-0600 local key-file fallback so setup remains available; that fallback protects against other unprivileged local users, but a copied state directory plus its key does not provide at-rest confidentiality. If a Secret Service-backed key later becomes unavailable, Friends fails closed and preserves encrypted state instead of generating a replacement.

This protects copied state data when the Secret Service is not included. It does not protect an unlocked desktop session or a compromised user account. NIP-44 message encryption still lacks forward secrecy; see `docs/private-messaging-security-migration.md`.

## Supported release

Security fixes are targeted at the current `4.18.x` release line. Older experimental/demo builds are not supported.

## Important boundaries

- Public **World**, **Circles**, and **Build Network** content is relay-readable by design. Never publish secrets, credentials, private URLs, personal addresses, sensitive logs, or tokens there.
- Current-to-current private messages use NIP-44 v2 with NIP-17/NIP-59 wrapping and signed kind-10050 inbox relay metadata.
- Direct chats can display a pairwise safety code derived from both public account keys. Compare it over a separate trusted channel; it detects a key mismatch only when both participants compare the code and does not provide forward secrecy.
- The private-messaging implementation has regression/vector coverage but has **not** received an independent security audit and does not provide forward secrecy. Do not treat Friends as a high-assurance messenger for highly sensitive secrets.
- Setup sharing is metadata/review-first. Remote community data must never be executed as shell code and Friends must never auto-install another user's setup or overwrite dotfiles.
- Shared links are restricted to HTTP(S) before opening.
- The plugin intentionally runs without a hosted account service; local signing/state material is stored under the user's local state directory and is intended to remain user-only.

## Reporting a vulnerability

Please do not publish exploit details, private keys, or sensitive reproduction data in a public issue.

Use GitHub's **Report a vulnerability / private vulnerability reporting** flow for this repository when it is available. If GitHub does not offer that control, open a minimal public issue that says a security contact is needed, without including the sensitive details, so a private reporting path can be arranged.

For ordinary non-sensitive bugs, use the normal GitHub issue tracker and include the Omarchy version, plugin version, relevant shell/QML errors, and a minimal reproduction.

## Release policy

A green unit test run alone is not considered sufficient for a release. Stable releases also require real Omarchy manifest/QML validation and a live runtime smoke pass. Network-protocol or cryptography claims should remain factual and should not describe the plugin as independently audited unless that changes in the future.
