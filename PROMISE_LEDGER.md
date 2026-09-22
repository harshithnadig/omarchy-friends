# Omarchy Friends v4.15 — promise ledger

This is the source of truth for v4.15. **Feature scope is frozen.** If something below is checked, do not rebuild it in another architecture.

## Human layer / messaging

- [x] Public Omarchy World presence.
- [x] Friend requests and private DMs through the existing Friends engine.
- [x] Private groups.
- [x] Public Circles/community chat.
- [x] Focus/co-working ritual.
- [x] Waves / lightweight social signals.
- [x] Direct invite links.
- [x] Safe `omarchy-friends://invite/<64-hex-public-key>` parser.
- [x] Idempotent desktop URI registration using the actual installed handler path.

## Standard private messaging migration

- [x] NIP-44 v2 implementation in `bin/omarchy_friends_private.py`.
- [x] Official NIP-44 v2 reference vector covered by CI.
- [x] ChaCha20/HMAC authentication tamper rejection.
- [x] NIP-17 kind-14 rumor structure for current-to-current Friends private messages.
- [x] NIP-59 kind-13 seal + kind-1059 gift wrap for relay-facing metadata protection.
- [x] Modern direct-message outer gift wrap hides plaintext and true sender identity.
- [x] Modern private-group outer gift wrap hides group id/name and other member identities.
- [x] Current Friends World presence advertises `nip44-v2`, `nip17-dm-v1`, and `nip59-gift-wrap-v1` capabilities.
- [x] Capability negotiation prefers the standards-based transport for current peers.
- [x] Legacy Friends ciphertext remains readable during the upgrade window.
- [x] Current client sends the historical kind-4 format to a friend whose current presence does not advertise modern private-message capabilities.
- [x] Engine-level tests cover modern delivery, legacy fallback and group metadata hiding.
- [x] Full two-user journey test routes NIP-59 gift wraps correctly.
- [ ] Independent security audit of the Friends implementation is NOT claimed or completed.
- [ ] NIP-44 does not provide forward secrecy; Friends must not be marketed as a high-assurance secret messenger.

The protocol migration is implemented. What remains is real two-install relay validation, not cryptographic invention.

## Discover / creation loop

- [x] Discover feed for useful community work rather than follower/engagement ranking.
- [x] Ideas and interest signals.
- [x] Idea -> Build Room.
- [x] Ship Log.
- [x] Contribution-oriented builder context from useful actions.
- [x] External share-text generator for public Build Network objects.
- [x] Local save/hide state controls.

## Build together

- [x] Build Rooms.
- [x] Roles needed and room joins.
- [x] Task states: todo / doing / done / blocked.
- [x] Build lifecycle: building / testing / shipped / archived.
- [x] GitHub repository links.
- [x] Explicit public-GitHub snapshot helper for recent commits/open PRs/open issues; HTTPS public repos only, no credentials.
- [x] Explicitly published Project Activity cards.
- [x] Challenge -> team/build path.

GitHub remains the source of truth for code and issue history. Friends is the human coordination/discovery layer.

## Help / Can Help / Pair

- [x] Human Help requests.
- [x] Bounded `what I / my AI already tried` context.
- [x] Safe optional environment labels: Omarchy version, architecture, GPU vendor and kernel version label only.
- [x] Help offers and solve/close lifecycle.
- [x] `Can Help`, `Pair`, and `Building` availability objects.
- [x] Skill + environment matching without popularity/follower ranking.
- [x] Stale availability automatically expires from the latest signed replacement event.
- [x] Private follow-up routes through existing Friends chat.

## Community memory

- [x] Solution Cards.
- [x] Worked / partial / did-not-work verification.
- [x] Environment context on verification.
- [x] Help -> Solution without retyping the original problem/environment.
- [x] Longer bounded relay lookback for durable knowledge.

Private chat is never silently summarized/published into community memory.

## Share setups

- [x] Setup Cards.
- [x] Safe shallow local setup inspection.
- [x] Local compare/review plan.
- [x] Individual Setup Component cards.
- [x] HTTP(S)-only component/dotfile links.
- [x] Copy/review workflow.
- [ ] Automatic apply/install is intentionally NOT implemented.

## Test network

- [x] Test requests.
- [x] Requested environment tags.
- [x] Signed pass/issue results.
- [x] Environment-aware result context.

## Omarchy Update Pulse

- [x] Explicit opt-in working / minor issue / rolled back reports.
- [x] Overall aggregate.
- [x] Similar-environment aggregate.
- [x] No hidden telemetry.

## Events / rituals

- [x] Event cards.
- [x] Going / Interested RSVP.
- [x] Build challenges.
- [x] Challenge joins/team metadata.
- [x] Existing Ship-It Friday/focus rituals remain in Friends.

## Safety / abuse / reliability

- [x] Signed Nostr Build Network objects.
- [x] Unknown object types fail closed.
- [x] Bounded text/list/object sizes and HTTP(S)-only shared URLs.
- [x] `file://` / `javascript:` URLs rejected from collaboration objects.
- [x] No arbitrary remote command execution.
- [x] No config auto-install or arbitrary file upload.
- [x] Existing Friends report/block controls remain in the social engine.
- [x] Build Network filters content from public keys already blocked in Friends, including nested derived activity.
- [x] Failed public publishes queue locally and retry in bounded batches.
- [x] Corrupt Build state is quarantined.
- [x] Explicit schema migration and private backup path.
- [x] Longer bounded community-memory lookback.
- [x] Per-author cache fairness so one valid Nostr identity cannot occupy the whole local cache.
- [x] Strict relay-event guards for oversized content, unreasonable future timestamps, and `d`/`type` tag disagreement with normalized payload.
- [x] QML action queue prevents timer status/refresh processes racing user writes.
- [x] Release health reports schema, queued publishes, filtered blocks and relay status.
- [x] CI compiles current Friends/Build modules, runs private-message standard + engine tests, the complete unit suite, remote-exec boundary and static release gate.

## UI

- [x] Liquid-glass V3 Build Network panel.
- [x] Reusable `GlassSurface.qml` and `GlassPill.qml` primitives.
- [x] Discover / Build / Share / Help / Community / Create surfaces.
- [x] Existing Friends UI retained to minimize regressions.
- [x] One active Build Network UI path; obsolete V1/V2 panels removed.
- [x] Can Help/Pair/Building controls wired.
- [x] Helper matches wired into Help requests.
- [x] Setup Component sharing wired.
- [x] Public GitHub snapshot/activity publishing wired.
- [x] Help -> Solution wired.
- [x] External Share wired.
- [x] Invite repair and release Health controls wired.
- [x] Visible `🛠 Build` entry in normal Friends while middle-click remains the direct shortcut.

## Distribution / adoption

- [x] Install flow documented.
- [x] Marketplace preparation notes exist.
- [x] First-50 liquidity/trust/habit launch playbook exists.
- [ ] Marketplace acceptance is external to this repository.
- [ ] Real-user liquidity requires actual Omarchy users; it cannot be coded.

## Final release gates — real Omarchy only

Repository-side v4.15 work is complete and CI is green. These are the remaining gates before stable:

1. [ ] `bash scripts/release-gate.sh` passes on the actual Omarchy installation with no `FAIL`.
2. [ ] Real `omarchy plugin validate .` and `qmllint` pass against installed shell imports.
3. [ ] Two current v4.15 instances exchange NIP-17/NIP-59 direct/group messages on real configured relays, with outer-event metadata inspection passing.
4. [ ] v4.15-to-legacy upgrade-compatibility test passes in both directions required by `FINAL_RELEASE_STATUS.md`.
5. [ ] Build Network two-instance relay test passes: publish/receive/update/dedupe, offline retry, helper expiry and block filtering.
6. [ ] Existing Friends regression passes: friend requests, DMs, groups, World, Circles, focus, block/report, profile/privacy and update flow.
7. [ ] A real `omarchy-friends://invite/...` click opens through the installed desktop handler and invalid shapes are rejected.
8. [ ] All six Build Network tabs pass visual/input/scroll/action-reachability inspection at normal laptop scale.

When all eight pass, cut v4.15 stable. Do not reopen feature brainstorming for this release.
