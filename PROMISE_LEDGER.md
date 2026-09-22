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
- [x] Friends applies a 65,535-byte plaintext application resource cap; it is not described as the NIP-44 protocol maximum.
- [x] NIP-17 kind-14 rumor structure for current-to-current Friends private messages.
- [x] NIP-59 kind-13 seal + kind-1059 gift wrap for relay-facing metadata protection.
- [x] Modern direct-message outer gift wrap hides plaintext and true sender identity.
- [x] Modern private-group outer gift wrap hides group id/name and other member identities.
- [x] Receiver rejects a gift wrap whose decrypted kind-14 rumor does not address the receiver.
- [x] Current Friends presence advertises NIP-44/NIP-17/NIP-59 plus inbox-relay capability.
- [x] Signed NIP-17 kind-10050 DM inbox relay lists are published and fetched.
- [x] Modern gift wraps route only to the recipient's verified configured inbox relays.
- [x] Remote relay lists are bounded and cannot create arbitrary outbound WebSocket destinations; Friends follows only overlap with locally configured relays.
- [x] Modern protocol/inbox state persists across restart so stale presence does not silently downgrade an established upgraded friendship.
- [x] Legacy Friends ciphertext remains readable during the upgrade window.
- [x] A never-upgraded friend can still receive the historical kind-4 Friends format during the compatibility window.
- [x] Engine-level tests cover modern inbox routing, wrong-inner-recipient rejection, restart persistence, legacy fallback and group metadata hiding.
- [x] Full two-user journey test routes NIP-59 gift wraps correctly.
- [ ] Independent security audit of the Friends implementation is NOT claimed or completed.
- [ ] NIP-44 does not provide forward secrecy; Friends must not be marketed as a high-assurance secret messenger.

The repo-side protocol migration is implemented. What remains is real two-install/public-relay validation, not more cryptographic invention.

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
- [x] One-shot write-capable migration workflows/scripts removed after use; normal CI remains read-only.

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

Repository-side v4.15 work is complete. These are the remaining gates before stable:

1. [ ] `bash scripts/release-gate.sh` passes on the actual Omarchy installation with no `FAIL`.
2. [ ] Real `omarchy plugin validate .` and `qmllint` pass against installed shell imports.
3. [ ] Two current v4.15 instances publish/fetch signed kind-10050 inbox lists and exchange NIP-17/NIP-59 direct/group messages only on the recipient's advertised configured inbox relays.
4. [ ] Relay-facing kind-1059 metadata inspection passes and wrong-inner-recipient rejection is confirmed on a real instance.
5. [ ] Restart persistence passes: modern protocol/inbox state survives and stale World presence does not downgrade the friendship.
6. [ ] v4.15-to-legacy upgrade-compatibility test passes as specified in `FINAL_RELEASE_STATUS.md`.
7. [ ] Build Network two-instance relay test passes: publish/receive/update/dedupe, offline retry, helper expiry and block filtering.
8. [ ] Existing Friends regression passes: friend requests, DMs, groups, World, Circles, focus, block/report, profile/privacy and update flow.
9. [ ] A real `omarchy-friends://invite/...` click opens through the installed desktop handler and invalid shapes are rejected.
10. [ ] All six Build Network tabs pass visual/input/scroll/action-reachability inspection at normal laptop scale.

If real public relays reject kind-10050/kind-1059 or demand authentication, record the concrete relay response before changing protocol code.

These unchecked items are external validation gates, not missing repository features. Codex should only implement a minimal fix when an actual gate demonstrates a concrete problem.

When all ten pass, cut v4.15 stable. Do not reopen feature brainstorming for this release, and do not merge `main` without Harshu's explicit instruction.