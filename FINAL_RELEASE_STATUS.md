# Omarchy Friends v4.15 — final release status

Feature scope is frozen. Repository-side v4.15 work is complete; do not add another product feature before release.

## Repo-side release candidate

- Product architecture: complete for the planned v4.15 scope.
- Build Network backend: complete.
- Liquid-glass V3 panel: implemented.
- Release runtime: `bin/build_network_app_v4.py`.
- `manifest.json` and the live Friends engine both advertise `4.15.0`.
- Build Network is visibly reachable from the normal Friends panel and remains available by middle-click.
- V3 UI exposes Can Help / Pair, helper matches, setup-component sharing, public GitHub pulse/activity publishing, Help -> Solution, external Share, invite repair and health diagnostics.
- Current-to-current Friends private messaging now uses NIP-44 v2 + NIP-17/NIP-59 gift wrapping through `bin/omarchy_friends_private.py`.
- Upgrade compatibility remains: current clients can decrypt historical Friends ciphertext and send legacy kind-4 DMs to a friend whose current presence does not advertise the v4.15 private-message capabilities.
- The standards implementation has official-vector, tamper/wrong-recipient, FriendsEngine DM/fallback, group-metadata-hiding and end-to-end journey coverage. The Friends implementation itself is not independently security-audited and must not be marketed as audited cryptography.

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
- CI compiles active Friends + Build modules, runs the NIP-44/NIP-17 transport tests, runs the complete unit suite, enforces the remote-execution safety boundary and runs the static release gate.

## Remaining gates — real Omarchy only

1. Run `bash scripts/release-gate.sh` on the actual Omarchy installation and require no `FAIL`.
2. Pass real `omarchy plugin validate .` and `qmllint -I "$OMARCHY_PATH/shell" ...` against the installed shell imports.
3. Run two isolated current v4.15 instances and verify direct DM + private group delivery over real configured relays. Inspect the relay-facing kind-1059 gift wrap and confirm plaintext/true sender/group id/group name/other group members are not exposed in the outer event.
4. Run an upgrade-compatibility test with one v4.15 instance and one pre-v4.15/legacy fixture: legacy peer receives a legacy kind-4 DM, while v4.15 can still decrypt legacy ciphertext. Do not remove compatibility code until the transition policy is deliberately changed in a future release.
5. Run the Build Network two-instance relay test: replacement/dedupe, offline publish retry, helper expiry and block filtering.
6. Regression-test existing Friends friend requests, DMs, private groups, World, Circles, focus, blocks/reporting and update flow.
7. Open a real `omarchy-friends://invite/<public-key>` URI through the desktop handler installed from the actual plugin path.
8. Visually inspect all six Build Network tabs at normal laptop scale for clipping, scroll/input usability and obvious action reachability.

## Stop condition

When those eight real-system gates pass, cut v4.15 stable. Do not reopen feature brainstorming for this release.
