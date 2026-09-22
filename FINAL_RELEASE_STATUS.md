# Omarchy Friends v4.15.1 — final release status

Feature scope is frozen. Repository-side v4.15 work is complete; do not add another product feature before release.

**Release posture:** Omarchy Friends v4.15.1 hotfix. The hide and restore safety bug is fixed without changing the v4.15 feature scope.

## Repository-side state

- Product architecture: complete for the planned v4.15 scope.
- Build Network backend: complete.
- Friends V3 is the preferred shell; Friends V2 is the compatibility fallback; `Panel.qml` is the final legacy fallback.
- Build Network uses `BuildNetworkPanelV3.qml -> BuildNetworkService.qml -> bin/build_network_app_v4.py` and is now **lazy-loaded only when opened** so normal Friends use does not start its Python/network work unnecessarily.
- `manifest.json` and the live Friends engine advertise `4.15.1`.
- The shared glass primitives now expose visible keyboard focus and keyboard activation for primary buttons, navigation items and pills, so the main product is not mouse-only.
- The latest release prep includes `SECURITY.md` and `RELEASE_NOTES_v4.15.md`.
- Private inbox listening fans in all configured NIP-17 inbox relays, so one silent relay cannot park the listener indefinitely.

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
- The persistent private inbox listener fans in all configured recipient relays and deduplicates duplicate gift wraps.
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

## Final validation completed

The final Public Beta validation was run on the real Omarchy machine at commit `7c2792123304e1cf8a88b29675790ebe634f7426`:

- `bash scripts/release-gate.sh` — PASS, 139 tests;
- `omarchy plugin validate .` — PASS;
- installed-Omarchy `qmllint` for active Friends, Build Network, service and shared-glass QML — PASS;
- source and installed checkout — exact commit match at `7c2792123304e1cf8a88b29675790ebe634f7426`;
- one shell restart and Friends popup open — Friends rendered and no new Friends/Build runtime warnings;
- real two-instance messaging, NIP-17/NIP-59 delivery, signed kind-10050 routing, private group delivery, restart persistence, Build retry, helper expiry and block filtering — PASS;
- `relay.damus.io` returned an HTTP 503 during one probe; other configured inbox relays delivered normally, so this was non-blocking.

The release-gate run above is the current verification record; the documentation changes in this commit do not alter runtime code, protocol behavior or the installed plugin.

## Public Beta limitations

- Private messaging has not had an independent external security audit.
- Public relay availability can vary, including intermittent relay timeouts or rejection.
- Exhaustive automated interaction testing of the native Omarchy layer-shell popup is limited.

The release is ready for owner merge/tag as Public Beta. Do not merge `main` automatically.

## Stop condition

Do not reopen architecture or feature brainstorming for v4.15. Fix only reproduced release blockers. Do not merge `main` until Harshu explicitly asks for the merge.
