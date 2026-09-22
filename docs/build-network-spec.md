# Omarchy Friends — Build Network v4.15 product architecture

Build Network is the collaboration workspace inside Omarchy Friends. It is a first-class surface alongside Chats, Requests, World, Circles and Me — it is **not** a mode hidden inside Circles.

The v4.15 feature scope is frozen. This document describes the implementation that exists today; it is not a speculative backlog.

## Product job

Friends solves the human/machine gaps that AI alone cannot: finding another real Omarchy user, testing on another environment, pairing for a short session, co-owning work, reviewing a setup, and preserving a verified solution for the next person.

GitHub remains the source of truth for code and issue history. Friends coordinates the people around that work.

## Six Build workspaces

### Discover

A compact view of useful recent public community work. There is no follower count, popularity leaderboard or fake activity.

### Build

- Ideas and interest signals.
- Idea -> Build Room conversion.
- Build Room roles and joins.
- Todo / doing / done / blocked tasks.
- Building / testing / shipped / archived lifecycle.
- Public HTTPS GitHub repository links.
- Explicit public GitHub snapshots and Project Activity publishing.

### Share

- Setup Cards with shallow, opt-in metadata.
- Local review/comparison with the user's own machine.
- Individual Setup Components such as plugins, themes, bars, fonts, wallpapers and keybinding references.
- Test Requests and signed pass/issue Test Results.

Setup sharing never automatically installs, executes or overwrites another user's machine.

### Help

- Human Help Requests.
- Bounded “what I / my AI already tried” context.
- Can Help / Pair / Building availability with expiry.
- Skill/environment helper matching.
- Private follow-up through the existing Friends conversation system.
- Help -> reusable Solution Card without copying a private chat transcript.

### Community

- Solution Cards and Worked / Partly / Did-not-work verification.
- Ship Log.
- Explicit opt-in Update Pulse reports.
- Events with Going / Interested RSVPs.
- Challenges and challenge joins/team paths.

### Create

A focused composer for the supported public Build Network object types. The UI does not expose arbitrary event construction or remote commands.

## Identity and transport

Build Network reuses the pseudonymous secp256k1 identity already owned by Friends. Public collaboration objects are signed Nostr parameterized-replaceable events (kind `30079`) and are relay-readable by design.

Private DMs and private groups are a separate Friends transport. Current peers use NIP-44 v2 + NIP-17/NIP-59 with signed kind-10050 inbox relay metadata. Build Network must not invent a second private-message or encryption system.

## Trust and safety boundaries

- Public Build objects are metadata/text only.
- Shared URLs are HTTP(S) only.
- No arbitrary shell execution.
- No automatic setup installation.
- No silent upload of files, logs, configs, tokens or secrets.
- Safe environment metadata is coarse and opt-in; hostname, username, IP address, device serials and file contents are excluded.
- Existing Friends blocks filter Build Network top-level and derived/nested activity locally.
- Remote object types and fields are allowlisted, normalized and bounded.
- Relay failure queues public publishes locally for bounded retry.
- Per-author cache fairness prevents one identity from crowding the whole cache.

## UI contract

The active path is:

```text
BarWidget.qml
  -> BuildNetworkPanelV3.qml
  -> BuildNetworkService.qml
  -> bin/build_network_app_v4.py
```

The Build workspace shares the same midnight/violet Glass primitives as Friends V3. Obsolete Build Network V1/V2 panels are not active product paths.

## Release rule

Repository-side functionality is implemented. Stable v4.15 still requires the actual-machine checks in `CODEX_REAL_SYSTEM_TEST.md`: installed Omarchy validation/qmllint, visual/input checks, two-client public-relay behavior, offline retry/dedupe/helper expiry/block filtering, private-message interoperability, legacy compatibility and desktop invite handling.

Do not add another feature category before those real-system gates pass.