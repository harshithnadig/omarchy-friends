### Repository URL

https://github.com/harshithnadig/omarchy-friends

### Category

Developer Tools

### Tags

bar, quickshell, system

### Suggest a missing tag

social, collaboration

### Maintainer notes

Omarchy Friends v4.15 is an Omarchy-native social and collaboration layer with two connected surfaces.

**Friends V3** provides pseudonymous live World discovery, separate Received/Sent connection requests, private one-to-one and small-group chats, a public Omarchy Circle room, focus rituals, direct invite links, and explicit profile/presence/privacy controls. Chats contains only conversations the user has actually opened; the full friends list lives behind New chat so requests and unused contacts do not bury active conversations.

**Build Network** provides Ideas -> Build Rooms, roles/tasks/lifecycle, explicit public-GitHub activity cards, Setup Cards/components with review-first comparison, a Test Network, Human Help, short-lived Can Help/Pair/Building availability, helper matching, Solution Cards/community verification, Ship Log, voluntary Update Pulse, events and challenges.

Public discovery/collaboration uses signed bounded Nostr events with a locally generated pseudonymous secp256k1 identity. World presence expires quickly; the plugin does not invent fake online users. Public World/Circles/Build data is relay-readable. Safe environment sharing is limited to coarse explicit labels and excludes hostname, username, IP address, serials and file contents.

Current-to-current private messages use NIP-44 v2 + NIP-17 kind-14 + NIP-59 seals/gift wraps and signed kind-10050 inbox relay lists. Remote inbox-relay metadata cannot create arbitrary outbound destinations because Friends follows only bounded overlap with locally configured relays. Legacy read/send compatibility remains for never-upgraded peers. The implementation has not received an independent security audit and NIP-44 does not provide forward secrecy, so the project does not claim high-assurance secure messaging.

The plugin does not remotely execute commands, silently upload logs/configs/files, or automatically install another person's setup. v4.15 also uses explicit user-triggered updates rather than a timer-driven background updater.

The repository includes the manifest, MIT license, install/removal instructions, unit/e2e/protocol tests, WebSocket resource-limit regression tests, static release gate, strict invite URI handler, V3 -> V2 -> legacy UI fallback chain, and a real-Omarchy validation checklist. Stable release still requires the documented installed-plugin/QML/render/relay tests.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
