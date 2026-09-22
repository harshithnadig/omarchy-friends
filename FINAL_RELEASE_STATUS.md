# Omarchy Friends v4.15 — final release status

Feature scope is frozen. Repository-side v4.15 work is complete; do not add another product feature before release.

## Repo-side release candidate

- Product architecture: complete for the planned v4.15 scope.
- Build Network backend: complete.
- Unified liquid-glass UI: `FriendsPanelV2.qml` is the preferred Friends shell and `BuildNetworkPanelV3.qml` is the matching Build workspace; the old `Panel.qml` remains only as automatic load-failure fallback.
- Release runtime: `bin/build_network_app_v4.py`.
- `manifest.json` and the live Friends engine both advertise `4.15.0`.
- Build Network is visibly reachable from the normal Friends panel and remains available by middle-click.
- V3 UI exposes Can Help / Pair, helper matches, setup-component sharing, public GitHub pulse/activity publishing, Help -> Solution, external Share, invite repair and health diagnostics.
- Current-to-current Friends private messaging uses NIP-44 v2 + NIP-17/NIP-59 gift wrapping through `bin/omarchy_friends_private.py`.
- Current clients publish signed NIP-17 kind-10050 DM inbox relay lists; modern gift wraps are routed only to the recipient's verified configured inbox relays. Remote relay URLs are followed only when they overlap the sender's locally configured Friends relay set.
- A modern friendship's protocol choice and cached inbox metadata survive state migration/restart, preventing stale World presence from silently downgrading an already-upgraded friendship.
- Incoming gift wraps are rejected when the decrypted kind-14 rumor does not actually address the receiver.
- Upgrade compatibility remains: current clients can decrypt historical Friends ciphertext and send legacy kind-4 DMs to a friend that has never advertised the complete v4.15 private-message capabilities.
- Friends applies a 65,535-byte NIP-44 plaintext resource cap; this is an application-level resource/DoS bound, not the NIP-44 protocol maximum.
- The standards implementation has official-vector, tamper/wrong-recipient, inbox-list/routing, restart persistence, FriendsEngine DM/fallback, group-metadata-hiding and end-to-end journey coverage. The Friends implementation itself is not independently security-audited and must not be marketed as audited cryptography.

## Release hardening implemented

- relay-failed public objects are queued locally and retried in bounded batches;
- stale Can Help / Pair availability expires from the latest signed replacement event;
- existing Friends blocks filter Build Network top-level and nested activity locally;
- corrupt Build state is quarantined;
- state schema migration creates a private backup;
- durable community knowledge has a longer bounded lookback;
- one Nostr identity cannot crowd the whole local cache because of per-author fairness limits;
- malformed relay events are rejected for bad metadata/tag agreement, oversized content and unreasonable future timestamps;
- Build Network QML work is serialized so timer refresh/status operations do not race user writes;
- health diagnostics and `scripts/release-gate.sh` are included;
- CI compiles active Friends + Build modules, runs the NIP-44/NIP-17/NIP-59/inbox-routing tests, runs the complete unit suite, enforces the remote-execution safety boundary and runs the static release gate;
- one-shot write-capable migration workflows/scripts are removed after applying the changes; normal release CI is read-only.

## Remaining gates — real Omarchy only

1. Run `bash scripts/release-gate.sh` on the actual Omarchy installation and require no `FAIL`.
2. Pass real `omarchy plugin validate .` and `qmllint -I "$OMARCHY_PATH/shell" ...` against the installed shell imports.
3. Run two isolated current v4.15 instances over real configured relays. Verify each publishes/fetches signed kind-10050 inbox metadata; direct DMs and private groups deliver as kind-1059 only through the recipient's advertised configured inbox relays; and the receiving listener sees them there.
4. Inspect captured relay-facing kind-1059 events and confirm plaintext, true sender, group id/name and other group members are not exposed. Confirm a gift wrap whose decrypted kind-14 rumor does not address the receiving client is rejected.
5. Restart both current instances and confirm the modern protocol marker/inbox cache persists and the friendship does not downgrade merely because World presence is stale.
6. Run an upgrade-compatibility test with one v4.15 instance and one pre-v4.15/legacy fixture: a never-upgraded peer receives a legacy kind-4 DM, while v4.15 can still decrypt legacy ciphertext. Do not remove compatibility code until the transition policy is deliberately changed in a future release.
7. Run the Build Network two-instance relay test: replacement/dedupe, offline publish retry, helper expiry and block filtering.
8. Regression-test existing Friends friend requests, DMs, private groups, World, Circles, focus, blocks/reporting and update flow.
9. Open a real `omarchy-friends://invite/<public-key>` URI through the desktop handler installed from the actual plugin path.
10. Visually inspect all six Build Network tabs at normal laptop scale for clipping, scroll/input usability and obvious action reachability.

If the selected public relays reject kind-10050/kind-1059 or require relay authentication, record the exact relay response and fix only the demonstrated interoperability issue; do not add speculative protocol code.

These ten items require the real Omarchy environment, actual public-relay behavior or rendered UI. Codex should **validate them and make only minimal fixes for concrete failures**; it should not invent additional repository-side features.

## Stop condition

When those ten real-system gates pass, cut v4.15 stable. Do not reopen feature brainstorming for this release. Do not merge `main` until Harshu explicitly asks.