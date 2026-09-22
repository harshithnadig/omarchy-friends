# Omarchy Friends — v4.15 product thesis

## North star

Omarchy Friends should feel like noticing another useful human in the Omarchy ecosystem, not opening another generic social network.

> **Real people, useful context, then a reason to build together.**

Every visible online person must come from a recent opted-in installation. Every public Build object must come from an explicit signed publish. Empty states must stay truthful; Friends does not fake presence, replies, engagement or activity.

## Why this product exists when AI agents already exist

AI can explain code, generate themes and help debug. Friends is valuable when the missing resource is another **real machine or human**:

- someone running a different GPU/architecture who can test your plugin;
- a builder who wants to co-own a plugin/theme/tool;
- a person who has already solved the same Omarchy-specific problem;
- a human who can review whether an AI-generated fix actually works;
- a real collaborator for a short pair/focus/build session;
- a setup component or Build Room worth joining.

GitHub remains the code/history source of truth. Friends is the live coordination, discovery and community-memory layer around it.

## v4.15 product loops

### Human connection

```text
World / direct invite
        ↓
Request → Accept
        ↓
Private conversation
        ↓
Focus / Build together
```

Requests are deliberately separated from Chats. Chats contains only conversations the user has opened, while the complete friends list stays behind New chat.

### Build loop

```text
Discover useful work
        ↓
Idea / Help / Setup / Build Room
        ↓
Chat / Pair / Join / Test
        ↓
Build / Solve / Verify
        ↓
Ship / Solution / Setup Component
        ↓
Share externally
        ↓
Another real Omarchy user joins
```

## Shipped v4.15 surfaces

### Friends V3

- conversation-only Chats with per-person/group history;
- separate Received/Sent Requests;
- New chat friend picker and private-group creation;
- live World discovery with All/New/Building/Friends filters and one clear relationship action per person;
- room-style public Omarchy Circle;
- Me with About, Presence and explicit Privacy controls;
- contextual Focus and Build-together actions;
- V3 -> V2 -> legacy safety fallback.

### Build Network

- Discover;
- Ideas -> Build Rooms;
- roles/tasks/lifecycle;
- public GitHub activity snapshots/cards;
- Setup Cards and individual components;
- Test Network;
- Human Help + short-lived Can Help/Pair/Building availability;
- helper matching;
- Solution Cards and community verification;
- Ship Log;
- voluntary Update Pulse;
- events/challenges;
- external share text and direct invite links.

### Private messaging

Current peers use the v4.15 NIP-44/NIP-17/NIP-59 path with signed kind-10050 inbox relay metadata. Modern protocol state is sticky across restart/stale World presence, while bounded legacy compatibility remains for peers that never upgraded.

This implementation is not independently security-audited and NIP-44 does not provide forward secrecy.

## Product principles

1. **Signals before feeds.** Avoid infinite engagement-first social design.
2. **Human usefulness before vanity.** No follower counts or popularity leaderboard.
3. **One clear action.** World person cards should not become a wall of tiny buttons.
4. **Conversations are conversations.** Requests and discovery do not belong in the active-chat rail.
5. **Review before machine mutation.** Setup sharing never silently installs or overwrites files.
6. **Explicit public/private boundaries.** Public relay-readable data must look public; private chat must never be silently summarized into community memory.
7. **No fake liquidity.** If nobody is online, say so and surface durable public work instead of invented users.
8. **Explicit updates.** v4.15 does not silently update itself in the background.
9. **AI assists; humans verify.** The product should make AI-generated work easier to test, review and co-build rather than pretend AI is the community.

## Non-goals for v4.15

- centralized hosted Friends accounts/social graph;
- fake users or AI-generated human replies;
- generic engagement feed or follower economy;
- automatic setup installation;
- arbitrary remote command execution;
- silent telemetry or file/log/config uploads;
- claims of independently audited/high-assurance cryptography;
- adding more feature categories before real users expose a concrete missing workflow.

## Release gates

Before v4.15 stable:

1. repository CI/release gate passes;
2. actual Omarchy plugin validation and qmllint pass;
3. Friends V3 Chats/Requests/World/Circles/Me render and interact correctly on the real shell;
4. all six Build tabs render and interact correctly;
5. real two-client kind-10050 + NIP-17/NIP-59 relay tests pass;
6. restart/anti-downgrade and legacy compatibility pass;
7. Build Network two-client retry/dedupe/helper-expiry/block behavior passes;
8. existing Friends behavior and fallback chain regressions pass;
9. installed-path invite URI opening passes;
10. no release-blocking security/privacy issue is found.

The detailed procedure is `CODEX_REAL_SYSTEM_TEST.md`; the authoritative shipped-scope list is `PROMISE_LEDGER.md`.

## After stable

Do not resume a speculative backlog automatically. First collect real-user friction from the initial cohort and prioritize only problems that repeatedly block connection, collaboration, testing, help or return usage.
