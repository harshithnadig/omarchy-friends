# Omarchy Friends Build Network — v4.14 release candidate

Build Network is the Omarchy-native collaboration layer inside Friends. The v4.14 product scope is frozen; remaining work is real-system validation, not feature invention.

## Open it

- **Left-click** Friends to open the normal Friends deck, then use the visible **🛠 Build** button.
- **Middle-click** Friends to jump directly to **Build Network**.
- **Right-click** Friends to cycle status.

## Active implementation

```text
BarWidget.qml
  -> BuildNetworkPanelV3.qml
  -> BuildNetworkService.qml
  -> bin/build_network_app_v4.py
  -> bin/build_network_app_v3.py / v2 collaboration layers
  -> bin/build_network_runtime.py
```

Core public-object models live in `bin/build_network.py`, `bin/build_network_social.py`, `bin/build_network_v2.py` and `bin/build_network_v3.py`.

## What v4.14 includes

- Discover feed for recent useful community work without follower/engagement ranking.
- Ideas -> Build Rooms -> roles/tasks -> testing/shipped lifecycle.
- Public GitHub snapshot and explicitly published project-activity cards.
- Setup Cards, safe local comparison and individual setup-component sharing.
- Community Test Network with safe environment labels.
- Human Help, Can Help / Pair / Build-with-me availability, helper matching and private Friends chat handoff.
- Help -> reusable Solution Card and community verification.
- Ship Log, voluntary Update Pulse, events and challenges.
- External share-text generation and `omarchy-friends://` invite handling.
- Local save/hide plus reuse of the existing Friends block list.

## Federation and release hardening

Public Build Network objects are signed with the existing pseudonymous Friends identity and use Nostr kind `30079` with bounded normalized metadata. Relay copies are de-duplicated and newer author/object versions replace older cached versions.

v4.14 also adds bounded offline retry, stale-helper expiry, corrupt-state quarantine, schema migration backup, longer bounded knowledge lookback, per-author cache fairness, malformed-event metadata/tag/timestamp/content checks, and serialized QML actions so refresh timers cannot race user writes.

## Safety boundary

Build Network cards are public signed metadata. They do **not** remotely execute commands, install components, upload configs/logs/files automatically, or expose hostname/username/IP/serial/file contents. Shared setup components are review/copy/open-link workflows only.

Safe optional environment labels are limited to coarse non-identifying information such as Omarchy version, architecture, GPU vendor category and kernel version label, and are only published by explicit user actions that include them.

Private chat stays in the existing Friends messaging layer. Its current encryption is application-specific and is not described as formally audited; standardized NIP-44 migration is intentionally a separate compatibility-tested release.

## Invite handler

`bin/omarchy-friends-open` accepts only:

```text
omarchy-friends://invite/<64-hex-public-key>
```

The v4.14 runtime installs an idempotent user-local desktop handler using the actual installed plugin path. The final desktop-open behavior still has to be verified on the real Omarchy machine.

## Final validation

Run on the actual Omarchy system:

```bash
bash scripts/release-gate.sh
```

Then complete `CODEX_REAL_SYSTEM_TEST.md`, including real `omarchy plugin validate .`, `qmllint`, two-instance relay tests, existing Friends regressions and desktop invite URI opening.

If those gates pass, cut v4.14 stable. Do not add another feature to this release.
