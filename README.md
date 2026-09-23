# Omarchy Friends 👥

**The live human layer for Omarchy — meet builders, chat, share setups, build together, test things on real machines, and preserve what the community learns.**

Omarchy Friends is built specifically for Omarchy. It combines a lightweight social/messaging layer with the **Build Network**, a collaboration surface for ideas, projects, setups, testing, human help, solutions, events and community shipping.

There are no hosted Friends accounts and no fake users. Public discovery is pseudonymous and federated over Nostr relays; private social state stays local unless a user explicitly sends or publishes something.

## Two surfaces, one product

### Friends Deck — left click

Friends V3 is focused on people and conversation without dumping every social state into one screen:

- **Chats** — only conversations you have actually opened or used. Each friend/group has its own private conversation; the full friends list stays behind **New chat** instead of cluttering the rail.
- **Requests** — separate **Received** and **Sent/pending** connection requests. Incoming requests do not appear inside Chats.
- **World** — recently active real Omarchy installations with search and All/New/Building/Friends filters. Each person gets one clear relationship action instead of a row of repeated micro-buttons.
- **Circles** — one public community room with a normal message stream and composer.
- **Me** — pseudonymous profile plus About, Presence and explicit Privacy controls.
- **Focus** — bounded 25-minute co-working/focus rituals from an active private conversation.
- **Local Radar** — optional LAN discovery for nearby opted-in Omarchy users.

The preferred shell is `FriendsPanelV3.qml`. `FriendsPanelV2.qml` remains as a compatibility fallback and `Panel.qml` is the final legacy safety fallback if both modern shells fail to load.

### Build Network — middle click or visible Build button

The Build Network is the workshop layer:

- **Discover** — recent useful community work rather than a generic engagement feed.
- **Ideas → Build Rooms** — show interest, form a team, declare roles, track tasks, move from building → testing → shipped.
- **GitHub links/activity** — keep GitHub as the code source of truth while Friends coordinates the humans around it.
- **Setup Cards** — share shallow setup metadata, compare it with your machine, and share individual components such as themes, plugins, bars, fonts, wallpapers and keybindings.
- **Test Network** — request hardware/environment testers and collect signed pass/issue results.
- **Human Help** — post what is broken plus a short summary of what you or your AI already tried.
- **Can Help / Pair** — builders can advertise short-lived availability; matching uses skills/environment overlap rather than follower counts.
- **Community Memory** — turn solved help into reusable Solution Cards and let other users verify whether a fix worked for them.
- **Ship Log** — share completed work.
- **Update Pulse** — explicit opt-in reports for working / minor issue / rolled back, including similar-environment aggregates.
- **Events and Challenges** — meetups, online sessions, build challenges, RSVPs and team paths.
- **Contribution context** — builds, tests, solutions, help and shipping are visible without turning Friends into a follower-count contest.

## Bar controls

- **Left-click:** Friends Deck.
- **Middle-click:** Build Network.
- **Right-click:** Cycle your Friends status.
- **Bar pill:** Shows live peer count or an active focus timer.

## Privacy and safety model

Public World / Circles / Build Network data is intentionally public and relay-readable. Do not put passwords, private URLs, secrets, personal addresses or sensitive logs into public cards.

Friends deliberately applies several hard boundaries:

- shared URLs must be HTTP(S);
- remote community data is treated as metadata/text, never shell code;
- Setup Cards and components **never auto-install or overwrite dotfiles**;
- safe environment sharing is limited to coarse labels such as Omarchy version, architecture, GPU vendor and kernel version;
- hostname, username, IP address, serial numbers and file contents are not part of Build Network environment sharing;
- existing Friends blocks are honored by the release-hardened Build Network status layer;
- failed Build Network publishes are kept locally and retried on a later sync;
- `Can Help / Pair` availability expires instead of creating stale forever-online helpers;
- Me exposes explicit controls for World visibility, active app, music, project, interests and room sharing.

### Private messaging security — v4.15

For two current Friends peers, private DMs and small-group messages use the standardized Nostr private-message stack implemented in `bin/omarchy_friends_private.py` and integrated by `bin/omarchy-friends`:

- **NIP-44 v2** for authenticated private-message encryption;
- **NIP-17 kind-14 rumors** for private-message structure;
- **NIP-59 kind-13 seals and kind-1059 gift wraps** so the relay-facing event does not expose the real sender, plaintext, group id/name or the other group members;
- **NIP-17 kind-10050 DM inbox relay lists** so current clients route gift wraps to the recipient's advertised inbox relays.

Friends publishes a signed inbox-relay list and listens on those inbox relays. A remote kind-10050 event is followed only for relay URLs that are also present in the local configured Friends relay set; the cached selection is bounded. This prevents an untrusted remote profile from causing arbitrary WebSocket egress, but it means current interoperability requires an overlap in configured relay sets.

During the upgrade window, a current client can still **read the historical Friends ciphertext format** and can send the historical kind-4 format to a friend that has never advertised the complete modern capability set. Once a friendship has advertised the modern protocol, that upgrade is remembered across stale presence and restarts rather than silently downgrading later.

Friends deliberately caps a NIP-44 plaintext at **65,535 bytes** as an application resource/DoS bound. That is a Friends limit, not the NIP-44 protocol maximum; normal chat envelopes are far smaller.

The dependency-free WebSocket transport also bounds individual frame size, cumulative fragmented-message size, fragment count and one overall receive deadline so a relay cannot keep a client busy indefinitely with tiny continuation frames. Those limits have dedicated regression tests.

CI covers the official NIP-44 v2 vector, authentication/tamper failures, wrong-recipient and wrong-inner-recipient rejection, signed kind-10050 handling, actual FriendsEngine inbox routing, restart-persistent upgrade state, old-peer fallback, group metadata hiding, the two-user journey, WebSocket fragmentation limits, Friends V3 information-architecture contracts and the complete repository suite. The Friends implementation itself has **not** received an independent security audit, so do not market the plugin as audited cryptography. NIP-44 also does not provide forward secrecy; users should not treat Friends as a high-assurance secure messenger for highly sensitive secrets.

The compatibility/design record is in `docs/private-messaging-security-migration.md`.

## Global discovery

World presence uses signed Nostr events with a locally generated secp256k1 identity. Presence expires quickly so World behaves like a live lobby rather than a permanent fake-online list.

Default relays:

```text
wss://relay.primal.net
wss://nos.lol
wss://purplerelay.com
wss://nostr.mom
wss://relay.damus.io
```

Advanced users can override the set with `OMARCHY_FRIENDS_RELAYS`.

New profiles are globally discoverable by their generated pseudonymous handle by default; basic avatar/status/focus metadata and the signed inbox-relay list are also public. Active-app name, music, project details/URL, interests and room are **off until explicitly enabled** in **Me → Privacy**. Presence events are readable by configured public relays when shared. Previously saved privacy choices are preserved during migration. Turning sharing off stops future publication but cannot guarantee removal of information already received or retained by relays; do not publish sensitive project details or links.

## Direct invites

Friends produces links like:

```text
omarchy-friends://invite/<public-key>
```

The URI handler validates the invite key and starts a friend request immediately when the link is opened; it is not a preview-only action. Opening the link therefore sends a network-visible request and introduction ping. The handler is registered in the user-local desktop database. The real installed and removal paths must still be validated on the target Omarchy machine before release.

Direct invite links can start the connection flow even when World has not cached the peer yet.

## Install

```bash
omarchy plugin add https://github.com/harshithnadig/omarchy-friends.git --enable
```

Explicit bar placement can be configured in `~/.config/omarchy/shell.json`:

```json
{
  "right": [
    { "id": "community.omarchy-friends" }
  ]
}
```

Remove with:

```bash
omarchy plugin remove community.omarchy-friends
```

Local state lives under:

```text
~/.local/state/omarchy-friends/
```

State files containing private signing material are intended to remain user-only.

## Development

Run the normal unit suite:

```bash
python3 -m unittest discover -s tests -v
```

Run the private-message standard/engine gates explicitly:

```bash
python3 -m unittest tests.test_private_messaging tests.test_private_messaging_engine -v
```

Run the final static/release gate:

```bash
bash scripts/release-gate.sh
```

On a real Omarchy machine also run:

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml FriendsPanelV3.qml FriendsPanelV2.qml Panel.qml Service.qml \
  BuildNetworkPanelV3.qml BuildNetworkService.qml \
  GlassSurface.qml GlassPill.qml GlassButton.qml GlassField.qml \
  GlassNavItem.qml GlassAvatar.qml
```

`CODEX_REAL_SYSTEM_TEST.md` is the final real-machine validation checklist. It explicitly checks Chats, Requests, World, Circles, Me, the fallback chain, all six Build Network tabs, actual relay behavior and rendered UI. `PROMISE_LEDGER.md` records the complete product-scope promise audit so future agents do not invent duplicate systems.

## Release rule

Do **not** merge the feature branch solely because CI is green. A release requires the real Omarchy plugin/QML pass, Friends V3 visual/interaction pass, two-instance relay synchronization including signed kind-10050 inbox routing and NIP-17/NIP-59 messaging, current-to-legacy compatibility, restart/anti-downgrade validation, existing Friends regression tests, URI opening validation, and version consistency between `manifest.json` and the live Friends engine.

Repository-side scope is frozen. From this point, code changes should be limited to small fixes for failures demonstrated by the real-system checklist. Do not merge `main` until Harshu explicitly asks.

## License

MIT License — Omarchy Community Contributors.
