# Omarchy Friends v4.15.0

**Release posture:** stable build intended for a public beta rollout.

v4.15 turns Omarchy Friends from the old experimental/demo experience into a real Omarchy-native social and collaboration plugin with a hardened runtime, modern private messaging, a clearer Friends information architecture, and the Build Network.

## What users get

### Friends

- **Chats** contains real opened private/group conversations instead of mixing in every social state.
- **Requests** separates Received and Sent/pending connection requests.
- **World** is a live pseudonymous Omarchy people-discovery surface with search and relationship-aware actions.
- **Circles** is the public Omarchy community room.
- **Me** exposes profile, presence, interests, status, invite links and explicit privacy controls.
- **New chat** owns the complete friends picker and private-group creation flow.
- Build Network can hand an existing friend directly back into the correct private conversation.
- Empty newly-created private groups stay visible before their first message.
- Shared private-message links are clickable only when they are HTTP(S).

### Build Network

- Discover useful community work.
- Turn Ideas into Build Rooms with roles, tasks and lifecycle state.
- Link public GitHub project activity while keeping GitHub as the code source of truth.
- Share Setup Cards and individual setup components without auto-installing remote configuration.
- Request real-machine testing and publish signed test results.
- Ask for Human Help, advertise time-limited Can Help / Pair availability, and find relevant builders.
- Preserve solved knowledge as Solution Cards with verification context.
- Publish Ship posts, update reports, events and challenges.
- Relay-failed publishes are saved locally and retried in bounded batches.

## Private messaging

Current Friends peers prefer:

- NIP-44 v2 authenticated encryption;
- NIP-17 kind-14 private-message structure;
- NIP-59 kind-13 seals and kind-1059 gift wraps;
- signed NIP-17 kind-10050 inbox relay lists.

Legacy read/send compatibility remains for peers that have never advertised the complete modern capability set. Modern protocol state persists across restarts so an upgraded friendship does not silently downgrade just because presence is stale.

The implementation is **not independently security-audited** and NIP-44 does not provide forward secrecy. Do not use Friends for highly sensitive secrets.

## Reliability and safety work

- Friends V3 -> V2 -> legacy UI fallback chain.
- Build Network lazy-loads only when opened, avoiding unnecessary Python/network work during normal Friends use.
- Keyboard focus/activation support on shared glass buttons, nav items and pills.
- Real Omarchy `omarchy plugin validate` and installed-import `qmllint` pass completed on the RC before the final release-prep changes.
- Python compile checks, private-message vectors, complete unit suite, remote-execution safety boundary and release gate run in CI.
- Bounded WebSocket frame/message/fragment/deadline handling.
- Corrupt Build state quarantine and schema backup.
- Block filtering, stale helper expiry, bounded offline retry and per-author cache fairness.
- No silent background updater; updates are explicit user actions.
- Remote community content is treated as data, not executable shell code.

## Visual direction

v4.15 uses the shared Friends glass primitives for translucent midnight surfaces with violet/cyan highlights and clear selected/focus states. The implementation deliberately keeps a safe QtQuick-only fallback rather than depending on an unverified blur/effects module that could prevent the plugin from loading on a user's Omarchy install.

## Installation

After this branch is merged/tagged, install through the normal Omarchy plugin command documented in `README.md`.

## Public beta expectations

The build is intended to be usable rather than demo material, but the first public rollout should still be described as **beta** so real-world Omarchy/relay combinations can surface compatibility issues without overstating maturity.

When reporting a bug, include:

- Omarchy version;
- Omarchy Friends version;
- whether Friends V3, V2 fallback or legacy fallback loaded;
- the relevant QML/runtime error;
- exact action that failed;
- relay health only when the problem is network-related.

See `SECURITY.md` for sensitive reports.
