# Omarchy Friends Build Network — v4.15 release candidate

Build Network is the Omarchy-native collaboration layer inside Friends. The v4.15 product scope is frozen; remaining work is real-system validation, not feature invention.

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

Private Friends messaging has a separate standards layer in `bin/omarchy_friends_private.py` using NIP-44 v2 plus NIP-17/NIP-59 for current peers. The Friends engine publishes/fetches signed NIP-17 kind-10050 DM inbox lists and routes modern gift wraps only through verified configured recipient inbox relays, while retaining bounded compatibility for older Friends installs.

## What v4.15 includes

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
- Current-peer private DMs/groups through NIP-44/NIP-17/NIP-59 gift wrapping and kind-10050 inbox routing.
- Restart-persistent modern-protocol state so stale World presence does not silently downgrade an upgraded friendship.
- Compatibility read/fallback for pre-v4.15 Friends private messages.

## Federation and release hardening

Public Build Network objects are signed with the existing pseudonymous Friends identity and use Nostr kind `30079` with bounded normalized metadata. Relay copies are de-duplicated and newer author/object versions replace older cached versions.

The release also adds bounded offline retry, stale-helper expiry, corrupt-state quarantine, schema migration backup, longer bounded knowledge lookback, per-author cache fairness, malformed-event metadata/tag/timestamp/content checks, and serialized QML actions so refresh timers cannot race user writes.

## Safety boundary

Build Network cards are public signed metadata. They do **not** remotely execute commands, install components, upload configs/logs/files automatically, or expose hostname/username/IP/serial/file contents. Shared setup components are review/copy/open-link workflows only.

Safe optional environment labels are limited to coarse non-identifying information such as Omarchy version, architecture, GPU vendor category and kernel version label, and are only published by explicit user actions that include them.

For private chat, a remote inbox relay URL is followed only if it overlaps the locally configured Friends relay set, preventing arbitrary remote relay metadata from creating new outbound network destinations. The Friends implementation itself has not received an independent security audit, NIP-44 does not provide forward secrecy, and the 65,535-byte plaintext ceiling is a Friends resource bound rather than the NIP-44 protocol maximum. Do not market Friends as an audited/high-assurance secure messenger.

## Invite handler

`bin/omarchy-friends-open` accepts only:

```text
omarchy-friends://invite/<64-hex-public-key>
```

The runtime installs an idempotent user-local desktop handler using the actual installed plugin path. The final desktop-open behavior still has to be verified on the real Omarchy machine.

## Final validation

Run on the actual Omarchy system:

```bash
bash scripts/release-gate.sh
```

Then complete `CODEX_REAL_SYSTEM_TEST.md`, including real `omarchy plugin validate .`, `qmllint`, kind-10050 inbox publication/fetch, current-to-current NIP-17/NIP-59 messaging, restart/anti-downgrade behavior, legacy compatibility, Build Network relay tests, existing Friends regressions and desktop invite URI opening.

Those are validation tasks, not prompts for another architecture or crypto rewrite. If the documented real-system gates pass, cut v4.15 stable. Do not add another feature to this release.