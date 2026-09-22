# Security policy

Omarchy Friends is a third-party Omarchy plugin. Omarchy plugins run inside the user's shell context and are not sandboxed, so security bugs in plugin code can affect the local desktop session.

## Supported release

Security fixes are targeted at the current `4.15.x` line once it is released. Older experimental/demo builds are not supported.

## Important boundaries

- Public **World**, **Circles**, and **Build Network** content is relay-readable by design. Never publish secrets, credentials, private URLs, personal addresses, sensitive logs, or tokens there.
- Current-to-current private messages use NIP-44 v2 with NIP-17/NIP-59 wrapping and signed kind-10050 inbox relay metadata.
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
