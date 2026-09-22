# Omarchy Friends v4.15.0 — final release status

Feature scope is frozen. Repository-side v4.15 work is complete; do not add another product feature before release.

**Release posture:** stable build intended for a public beta rollout. The remaining checks are real-machine interoperability checks, not permission to redesign the product.

## Repository-side state

- Product architecture: complete for the planned v4.15 scope.
- Build Network backend: complete.
- Friends V3 is the preferred shell; Friends V2 is the compatibility fallback; `Panel.qml` is the final legacy fallback.
- Build Network uses `BuildNetworkPanelV3.qml -> BuildNetworkService.qml -> bin/build_network_app_v4.py` and is now **lazy-loaded only when opened** so normal Friends use does not start its Python/network work unnecessarily.
- `manifest.json` and the live Friends engine advertise `4.15.0`.
- The shared glass primitives now expose visible keyboard focus and keyboard activation for primary buttons, navigation items and pills, so the main product is not mouse-only.
- The latest release prep includes `SECURITY.md` and `RELEASE_NOTES_v4.15.md`.

## Friends V3 product behavior

- **Chats** contains opened/history conversations only.
- **New chat** owns the full friend picker and private-group creation.
- **Requests** has separate Received and Sent/pending states.
- **World** is people discovery with search + All/New/Building/Friends filters and one truthful relationship action per person.
- **Circles** is one public community room with a normal message stream and composer.
- **Me** separates About, Presence and Privacy controls.
- Build Network can hand an existing friend directly back into the correct private conversation without re-sending a request.
- Incoming/outgoing/nonfriend Build handoffs route to Accept/Requested/Connect states instead of pretending chat is available.
- Newly created private groups remain visible before the first message.
- Shared private-message URLs open only through the explicit HTTP(S) path.
- Sent-request action layout reserves width for Pending/Cancel controls instead of clipping text.

## Private messaging / safety

- Current-to-current Friends private messaging uses NIP-44 v2 + NIP-17 kind-14 + NIP-59 kind-13 seals/kind-1059 gift wraps.
- Current clients publish signed NIP-17 kind-10050 DM inbox relay lists and use only recipient relay metadata that overlaps locally configured Friends relays.
- A modern friendship's protocol choice/inbox metadata survives restart, preventing stale presence from silently downgrading an upgraded friendship.
- Incoming gift wraps fail closed when recipient/inner-rumor checks do not match.
- Legacy read/send compatibility remains for peers that have never advertised the complete modern capability set.
- Friends applies bounded NIP-44 payload/resource limits and bounded WebSocket frame/message/fragment/deadline handling.
- The implementation is **not independently security-audited** and must not be marketed as audited cryptography or as a high-assurance messenger.
- Remote Build/community content is data only: no remote shell execution and no automatic setup installation/overwrite.

## Release hardening implemented

- relay-failed Build objects are queued locally and retried in bounded batches;
- stale Can Help / Pair availability expires;
- Friends blocks filter Build Network top-level and nested activity locally;
- corrupt Build state is quarantined and schema migration creates a private backup;
- per-author cache fairness prevents one identity from crowding the local cache;
- malformed/future/oversized public events are rejected;
- Build Network backend actions are serialized;
- V3 -> V2 -> legacy UI fallback protects installs from a modern-shell load regression;
- Build Network is lazy-loaded to reduce idle work and failure surface;
- shared glass controls expose keyboard focus + Enter/Return/Space activation;
- no silent background updater; updates remain explicit user actions;
- release CI is read-only and one-shot patcher workflows/scripts are absent.

## Validation already completed

The RC was exercised on a real Omarchy machine and the following passed before the last small accessibility/lazy-load release-prep changes:

- `bash scripts/release-gate.sh` — PASS;
- complete unit suite — PASS (132 tests at that point);
- private messaging standard/engine checks — 13/13 PASS;
- `omarchy plugin validate` — PASS;
- installed-Omarchy `qmllint` for requested Friends/Build files — PASS;
- live RC install and shell restart — Friends loaded without warnings;
- relay health — 5/5 reachable in that run, zero reported errors/queued publishes;
- invalid invite-handler inputs were rejected correctly.

After the final code-side pass, CI also passed on commit `a1fd5caee89578b329040d2871aa6ff6e5ceee74`, including Python compile, private-message vectors, complete unit suite, remote-execution safety boundary and static release gate. Subsequent release-prep commits add regression coverage/documentation only and must finish the same CI before merge.

## Only remaining Codex / real-machine checks

These are the few things that cannot be honestly completed from the repository connection alone:

1. **Latest-head runtime smoke:** pull the current `feature/build-network` head, run `omarchy plugin validate .`, installed-import `qmllint`, restart the shell, open Friends and Build once, and verify there are no new QML warnings after the keyboard/lazy-load changes.
2. **Real interaction + fallback smoke:** keyboard-click through Chats, Requests, World, Circles, Me and all six Build sections; verify friend request send/accept/decline/cancel, one DM, one group creation/message, Build -> existing-friend chat handoff, update button, real `omarchy-friends://invite/...` desktop dispatch, and force V3 failure once to prove V2/legacy fallback still recovers. Mouse-only middle/right-click behavior is not a release blocker because Build/status have visible UI paths.
3. **Two-instance network check:** two current v4.15 installs over real configured relays must complete friend request -> accept -> NIP-17/NIP-59 DM both directions, signed kind-10050 inbox routing, one private-group message, restart/anti-downgrade persistence, and the Build Network two-instance retry/block/helper-expiry smoke. Record exact relay errors if any instead of adding speculative protocol code.

If these three checks pass without a release-blocking regression, v4.15.0 is ready to merge/tag as the stable build and announce publicly as **beta**.

## Stop condition

Do not reopen architecture or feature brainstorming for v4.15. Fix only reproduced release blockers. Do not merge `main` until Harshu explicitly asks for the merge.
