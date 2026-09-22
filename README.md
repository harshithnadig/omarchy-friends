# Omarchy Friends 👥

**The live human layer for Omarchy — meet builders, chat, share setups, build together, test things on real machines, and preserve what the community learns.**

Omarchy Friends is built specifically for Omarchy. It combines a lightweight social/messaging layer with the **Build Network**, a collaboration surface for ideas, projects, setups, testing, human help, solutions, events and community shipping.

There are no hosted Friends accounts and no fake users. Public discovery is pseudonymous and federated over Nostr relays; private social state stays local unless a user explicitly sends or publishes something.

## Two surfaces, one product

### Friends Deck — left click

The existing Friends experience remains focused on people and conversation:

- **Chats** — explicit friend requests, private DMs and small private groups.
- **World** — recently active real Omarchy installations, waves, Sparks and focus invitations.
- **Circles** — public community chat.
- **Me** — pseudonymous profile, interests, status, project beacon, privacy controls and invites.
- **Focus** — bounded 25-minute co-working/focus rituals.
- **Local Radar** — optional LAN discovery for nearby opted-in Omarchy users.

### Build Network — middle click

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
- `Can Help / Pair` availability expires instead of creating stale forever-online helpers.

### Private messaging security

Accepted friends can exchange encrypted DMs and encrypted small-group messages through the existing Friends engine. The current implementation predates the Build Network and uses an application-specific secp256k1 shared-secret construction.

A migration to a standardized audited Nostr private-message scheme (NIP-44 v2, with NIP-17/NIP-59 evaluated for metadata protection) is tracked separately in `docs/private-messaging-security-migration.md`. Do not market the current implementation as formally audited cryptography.

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

The generated pseudonym is visible globally by default because discovery is the point of the plugin. You can disable global visibility immediately from **Me**.

## Direct invites

Friends produces links like:

```text
omarchy-friends://invite/<public-key>
```

The current release includes a strict URI parser and best-effort user-local desktop registration. The real installed path must still be validated on the target Omarchy machine before release.

Pasting a link or Friend Code into the Friends Deck remains a fallback.

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

Run the final static/release gate:

```bash
bash scripts/release-gate.sh
```

On a real Omarchy machine also run:

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml Panel.qml Service.qml \
  BuildNetworkPanelV3.qml BuildNetworkService.qml \
  GlassSurface.qml GlassPill.qml
```

`CODEX_REAL_SYSTEM_TEST.md` is the final real-machine validation checklist. `PROMISE_LEDGER.md` records the complete product-scope promise audit so future agents do not invent duplicate systems.

## Release rule

Do **not** merge the Build Network branch solely because Python CI is green. A release requires the real Omarchy plugin/QML pass, two-instance relay synchronization, existing Friends regression tests, URI opening validation, and version consistency between `manifest.json` and the live Friends engine.

## License

MIT License — Omarchy Community Contributors.
