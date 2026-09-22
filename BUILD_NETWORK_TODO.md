# Omarchy Friends v4.15 RC — implementation status

This file used to track the v4.14 Build Network build. It is retained only as a short status pointer so older links do not lead future contributors to obsolete instructions.

**Current sources of truth:**

1. `PROMISE_LEDGER.md` — complete shipped/not-shipped promise audit.
2. `FINAL_RELEASE_STATUS.md` — release-candidate status and remaining real-system gates.
3. `CODEX_REAL_SYSTEM_TEST.md` — exact validation procedure for the actual Omarchy machine.
4. `docs/ui-design-v415.md` — Friends V3 + Build Network UI contract.

## Repository-side v4.15 scope

Implemented on `feature/build-network`:

- Friends V3 with conversation-only Chats, separate Received/Sent Requests, New chat picker, simplified World, room-style Circles and explicit Profile privacy controls;
- V3 -> V2 -> legacy UI fallback chain;
- Ideas -> Build Rooms, roles/tasks/lifecycle and public GitHub activity;
- Setup Cards/components with review/compare workflows;
- Test Network, Human Help, Can Help/Pair/Building availability and helper matching;
- Solution Cards/community verification, Ship Log, Update Pulse, events and challenges;
- signed bounded Nostr federation, retry/dedupe/cache hardening and Friends block reuse;
- NIP-44 v2 + NIP-17/NIP-59 current-peer private messaging with kind-10050 inbox routing and bounded legacy compatibility;
- strict invite URI handling;
- explicit user-triggered updates only — no silent background updater;
- CI for protocol vectors, unit/e2e behavior, WebSocket fragmentation limits, Friends V3 information architecture, remote-exec boundary and release gate.

## Intentionally not implemented

- automatic install/apply of another person's setup;
- arbitrary remote shell/code execution;
- automatic upload of logs, configs, secrets or private files;
- claims of an independent cryptographic security audit;
- claims of forward secrecy for NIP-44.

## Remaining work

Only the real-system gates in `FINAL_RELEASE_STATUS.md` remain: installed Omarchy validation/qmllint, rendered UI and interaction checks, real public-relay/two-client tests, legacy compatibility, existing Friends regression and desktop invite handling.

Do not treat this file as a new feature backlog. Fix only concrete failures demonstrated by the real-system checklist before v4.15 stable.
