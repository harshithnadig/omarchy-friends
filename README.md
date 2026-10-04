# Omarchy Friends 👥

**The live human layer for Omarchy — meet builders, chat, share setups, build together, test things on real machines, and preserve what the community learns.**

Omarchy Friends is built specifically for Omarchy. It combines a lightweight social/messaging layer with the **Build Network**, a collaboration surface for ideas, projects, setups, testing, human help, solutions, events and community shipping.

There are no hosted Friends accounts and no fake users. World discovery is pseudonymous and federated over Nostr relays, with minimal presence enabled by default for new profiles while online. Private chat content stays local unless a user sends it to a conversation.

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

New profiles are discoverable in World by default so people can find each other without setup. While online, the app publishes a stable public key, generated handle, avatar, status and inbox-relay list to configured public relays; this is pseudonymous but linkable over time, not anonymous. Relay operators or other recipients may retain published data after visibility is turned off. Users can switch **Visible in World** off in Me → Privacy at any time. Existing saved visibility choices, including hidden profiles, are preserved when upgrading. World shows only real Friends installations with fresh presence and compatible relay reachability; an empty list does not mean your account or chats are missing. Chat contents and history are never part of World presence.

Hiding your own beacon does not turn off World browsing or your private inbox. Friends continues syncing incoming messages and connection events while hidden; only your periodic discovery presence stops.

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

Current Friends clients support NIP-17 replies, reactions, author-checked encrypted edits for text-only messages within 15 minutes, and encrypted kind-5 deletion for messages you sent. Edits use a Friends envelope extension: older Friends clients keep the original message, while unrelated NIP-17 clients may show an edit as a separate message. The legacy Friends compatibility path carries edits inside its existing encrypted envelope. Deletion is best effort: a relay acknowledgement is not proof that every recipient received it, and it cannot erase copies a client, export, backup or relay already retained.

Encrypted read receipts are optional and disabled by default. When enabled, opening a direct chat or group sends an encrypted receipt to compatible Friends peers; other NIP-17 clients may display the receipt as an ordinary short message.

Typing indicators are enabled by default for direct chats with compatible, connected Friends peers and can be disabled in **Me → Privacy**. Each signal is NIP-44 encrypted inside a NIP-59 ephemeral gift wrap (kind 21059); its inner kind 20000 payload is held only in the user's volatile runtime directory for at most 12 seconds and never enters message history or notifications. Signals stop after inactivity, when sending, or when changing chats. Groups and older clients do not receive them. NIP-59 ephemeral events are required not to be stored by relays, but relays still see the recipient's public key and event timing while routing them.

Chat rows show per-conversation unread counts using encrypted local read cursors. Opening a chat marks its current messages read on this device. This local unread tracking is separate from the optional encrypted read receipts described above.

Pin up to 20 direct or group conversations from the chat header. Pins are stored in the encrypted local state and sort ahead of recent conversations; they are not synced to other devices.

Mute a direct or group conversation from its header to suppress new-message notifications on this device. Messages remain in the chat and still count as unread; mute preferences stay in encrypted local state and are not synced.

Friends deliberately caps a NIP-44 plaintext at **65,535 bytes** as an application resource/DoS bound. That is a Friends limit, not the NIP-44 protocol maximum; normal chat envelopes are far smaller.

The dependency-free WebSocket transport also bounds individual frame size, cumulative fragmented-message size, fragment count and one overall receive deadline so a relay cannot keep a client busy indefinitely with tiny continuation frames. Those limits have dedicated regression tests.

CI covers the official NIP-44 v2 vector, authentication/tamper failures, wrong-recipient and wrong-inner-recipient rejection, signed kind-10050 handling, actual FriendsEngine inbox routing, restart-persistent upgrade state, old-peer fallback, group metadata hiding, the two-user journey, WebSocket fragmentation limits, Friends V3 information-architecture contracts and the complete repository suite. The Friends implementation itself has **not** received an independent security audit, so do not market the plugin as audited cryptography. NIP-44 also does not provide forward secrecy; users should not treat Friends as a high-assurance secure messenger for highly sensitive secrets.

The compatibility/design record is in `docs/private-messaging-security-migration.md`.

Direct chats also expose **Verify security code** in the chat's More menu. Compare the pairwise account-key fingerprint with the other person through a separate trusted channel to detect a changed or mismatched identity key. This does not verify a real-world identity by itself and does not add forward secrecy.

## Large files and local history

Files and folders can be sent up to 100 MiB through a user-configured HTTPS Blossom server. Friends encrypts file bytes with streaming AES-256-GCM before upload; only the encrypted pointer and decryption metadata are placed in the end-to-end encrypted message. The server must accept a 100 MiB upload and retain the blob for recipients to fetch. Install `python-cryptography` on the host for encrypted local history and large-file encryption/decryption.

Peers that advertise Friends' `nip17-file-kind15-v1` capability receive Blossom attachments as encrypted NIP-17 kind-15 file messages with the standard file type, AES-GCM key/nonce, ciphertext hash and size fields. Older NIP-17 peers continue to receive the existing kind-14 Friends envelope.

Friends stores the local message journal as individually authenticated encrypted records, with a separate local key restricted to the current user. Writes use SQLite full synchronization under the plugin's private state directory. Outgoing messages are durably recorded before network delivery is attempted; failed delivery stays marked as unconfirmed. The journal has no message-count pruning limit.

When a DM activity record exists but its message bodies are missing locally, the empty thread offers an explicit **Check inbox relays for history** action. It queries the configured NIP-17 inbox relays for up to 500 gift-wrapped messages per page, validates and decrypts matching messages locally, and saves them in the encrypted journal without generating new-message notifications. If a relay has more pages, the conversation header keeps an **Older** action available and advances a local per-relay timestamp cursor. Relay retention is outside Friends' control, so messages no longer retained there cannot be recovered.

## Global discovery

World presence uses signed Nostr events with a locally generated secp256k1 identity. Presence expires quickly so World behaves like a live lobby rather than a permanent fake-online list.

World lists people who have Omarchy Friends installed, have World visibility
on, and published a recent presence. New profiles are visible by default while
online; existing profiles keep their saved visibility choice after upgrading.
If the directory is empty while relays are healthy, there may simply be no
other users online yet; use the invite action to bring someone in. You can
browse World with your own profile hidden.

Default relays:

```text
wss://relay.primal.net
wss://nos.lol
wss://purplerelay.com
wss://nostr.mom
wss://relay.damus.io
```

Advanced users can override the set with `OMARCHY_FRIENDS_RELAYS`.

New profiles are visible to configured public relays by default while online. Their stable pseudonymous public key, generated handle, basic avatar/status/focus metadata and signed inbox-relay list are public. Relay operators or other recipients may retain published data after visibility is turned off. Existing profiles keep their saved privacy choice on upgrade, including an explicit hidden setting. Active-app name, music, project details/URL, interests and room remain **off until separately enabled** in **Me → Privacy**. Chat contents are never part of World presence. Do not publish sensitive project details or links.

Local Radar/LAN presence is **off on new profiles** because discovery uses unauthenticated UDP broadcast visible to devices on the local network. Enable **Me → Privacy → LAN sharing** only on networks where you want nearby Omarchy users to discover this profile. Existing saved LAN-sharing choices are preserved during migration.

## Direct invites

Friends produces links like:

```text
omarchy-friends://invite/<public-key>
```

The URI handler validates the invite key and starts a friend request immediately when the link is opened; it is not a preview-only action. Opening the link therefore sends a network-visible request and introduction ping. The handler is registered in the user-local desktop database. The real installed and removal paths must still be validated on the target Omarchy machine before release.

Direct invite links can start the connection flow even when World has not cached the peer yet.

## Install

Encrypted local chat history requires Arch's `python-cryptography` package. The file and folder chooser also requires the Python D-Bus and GLib bindings; a working desktop file-chooser portal must be available in the Omarchy session. Install the bindings before using Friends:

```bash
sudo pacman -S python-cryptography python-dbus python-gobject
```

Without `python-cryptography`, Friends cannot open its encrypted local state. Without the D-Bus/GLib bindings or a file-chooser portal backend, file and folder selection is unavailable. These are host dependencies and are not installed automatically by the plugin manager.

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
