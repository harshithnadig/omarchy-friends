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

## Validation record

The earlier Public Beta validation was run at commit `7c2792123304e1cf8a88b29675790ebe634f7426`. Its two-instance relay and Build Network results below are historical evidence for that commit, not a fresh pass on the current hotfix:

- `bash scripts/release-gate.sh` — PASS, 139 tests;
- `omarchy plugin validate .` — PASS;
- installed-Omarchy `qmllint` for active Friends, Build Network, service and shared-glass QML — PASS;
- source and installed checkout matched at `7c2792123304e1cf8a88b29675790ebe634f7426`;
- one shell restart and Friends popup open — Friends rendered and no new Friends/Build runtime warnings;
- real two-instance messaging, NIP-17/NIP-59 delivery, signed kind-10050 routing, private group delivery, restart persistence, Build retry, helper expiry and block filtering — PASS;
- `relay.damus.io` returned an HTTP 503 during one probe; other configured inbox relays delivered normally, so this was non-blocking.

The current hotfix was re-audited on the real Omarchy machine at runtime commit `86406fe665c8ca2335c1f7214818a9c6c91a8c4e`:

- `bash scripts/release-gate.sh` — PASS, 159 tests;
- installed `omarchy plugin validate` — PASS;
- installed-Omarchy `qmllint` for active Friends, Build Network, services, fallbacks and shared glass QML — PASS;
- source and installed checkout matched at the runtime commit above;
- Friends popup opened and visually rendered; it was closed normally afterward;
- no Friends/Build QML warnings appeared in the inspected shell logs;
- Build Network was deliberately not opened during this check because the previous live Build popup had captured/blurred the desktop;
- two-instance relay delivery and fallback UI were not freshly exercised on this hotfix commit.

The current local working-tree candidate has parent `923a40a37e8f7a6535f9db55c54ea4236e575201` plus uncommitted changes:

- `bash scripts/release-gate.sh` — PASS, 188 tests in the source checkout after the mutual-request replay, profile-copy, rate-limited NIP-17 retry, availability-field-label, shared GlassField accessibility, and relay sync acknowledgement fixes;
- `omarchy plugin validate .` — PASS in both release-gate runs;
- installed-Omarchy `qmllint` for active panels, all fallbacks, services and shared-glass QML — PASS in both release-gate runs;
- `git diff --check` — PASS; all modified runtime and test files compared equal between source and installed checkouts;
- regressions cover private state/migration, keyboard selection/focus and accessible-role/name contracts, feedback-entry paths, Build-to-chat fallback, strict invite URI parsing, mutual-request replay suppression, rate-limited NIP-17 redelivery, and relay sync awaiting OK acknowledgement after EOSE;
- Luna's read-only accessibility review found that the shared `GlassField` editors lacked accessible names. Both the single-line `TextInput` and multiline `TextArea` now receive an explicit accessible name, fall back to their placeholder, then to `Text field`; the source and installed plugin copies match. The regression currently asserts the name wiring for both editor branches (not runtime screen-reader narration);
- a subsequent adversarial review and live relay probe reproduced seven additional defects and added minimal fixes/regressions: accepted/declined/cancelled and auto-mutual friend requests could reappear when relay history replayed; malformed deeply nested relay JSON could terminate a persistent listener; URI registration could report success based only on a desktop file; signed events with malformed tag row shapes or non-integer timestamp/kind fields were accepted; valid NIP-17 rumors could reappear after generic dedupe cache churn; and explicit World refresh used too narrow a kind-1059 time filter for NIP-59 randomized timestamps. Full source and installed checkout gates pass for all seven fixes;
- a further reproduced NIP-17 loss case marked a valid rumor deduplicated before per-author rate-limit acceptance; a relay redelivery was consequently discarded. Dedupe bookkeeping now occurs only after the rate limiter accepts the message, with a fail-before/pass-after retry regression;
- a live relay synchronization race was identified and resolved in `_global_relay_sync`: when Nostr relays returned all 4 subscription `EOSE` messages before processing and emitting the event `OK` acknowledgement, the sync loop terminated prematurely on `len(eose) == 4`, falsely marking presence as unaccepted (`"Relays reached, but presence was not accepted"`). The loop now continues waiting for matching `OK` acknowledgements up to a bounded window, properly recording `accepted: true` and `acknowledged: true` across all reachable relays. This was covered by unit test `test_relay_sync_waits_for_ok_when_eose_arrives_first`;
- the invite handler was registered as `omarchy-friends.desktop`, pointing to the installed handler. Malformed URLs with wrong scheme/host/key, extra path slashes, query/fragment delimiters and surrounding whitespace are rejected before request dispatch. The valid desktop GUI dispatch has not been run;
- an isolated two-client Build Network smoke passed: a Can Help helper published and appeared at the peer; an Idea queued after a deliberate local `ConnectionRefusedError`, retried when relays were restored and appeared once at the peer; block filtering hid the author's Idea/room; unblocking restored the room, peer Join and task-update propagation worked. Helper expiry is covered by the simulated-time regression test, not a two-machine wall-clock wait;
- a fresh three-client real-relay test using isolated temporary states passed friend request/accept for A-B and A-C, modern-protocol capability checks, A→B and B→A private DMs, private-group creation/invites, and one group message stored exactly once by B and C through live multi-relay listeners. Each received kind-1059 event was observed via `wss://relay.primal.net`, `wss://nos.lol`, and `wss://purplerelay.com`; sends were accepted on available relays. One B→A publish saw a TLS hostname-mismatch failure at `nos.lol` while `relay.primal.net` and `purplerelay.com` accepted it and delivery passed. These public QA identities/events were disposable pseudonyms, but relay history is public/relay-controlled and cannot be reliably erased;
- before the catch-up fix, a separate listener-free probe published kind-1059 DMs successfully but repeated normal global refreshes did not retrieve them; the kind-1059 query's last-sync delta was narrower than the two-day randomized wrapper timestamp range. After widening the query, a fresh two-client public-relay check passed without persistent listeners: A's kind-1059 DM was accepted by three relays; B's normal World refresh retrieved/stored exactly one copy and observed that event from `relay.primal.net`, `nos.lol`, and `purplerelay.com`;
- intermittent `wss://relay.damus.io: OSError` occurred during ordinary syncs; other configured relays synced. The deliberate offline probe failed with `ConnectionRefusedError` at `wss://127.0.0.1:1` as expected;
- current listener/daemon sampling after a plugin rescan showed the same two PIDs for 60 seconds; each sampled at approximately 1.5–2.0% CPU and 0.2% memory. This is a bounded sample, not a long-duration soak;
- the pre-restart live pass visited Chats, Requests, World, Circles and Me, plus all six Build Network tabs (Discover, Build, Share, Help, Community, Create). It showed blank Help availability inputs and an old clipped Me subtitle not present in source/installed QML. After a supported full `omarchy restart shell` with Stay Awake enabled, the fresh Chats popup fit within its bounds, showed `Friends connected`, and had no visible fallback/error banner. Keyboard navigation then opened Me; the fresh header copy `Pseudonymous profile · sharing is opt-in.` fit without clipping. Help placeholders and the Build screen have not been visually confirmed after the restart;
- the Help tab screenshot reproduced two unlabeled blank availability inputs because standard `TextInput` does not support `placeholderText` in QtQuick and produced a runtime load error. Both inputs now use `TextField` with `background: null`, `padding: 0`, `placeholderTextColor: faint`, and accessible names, with strengthened regression coverage asserting that `availabilityColumn` uses `TextField` and no unsupported `TextInput` properties. The source and installed checkouts match;
- the six Build tabs render after the supported plugin rescan. Static state confirms Save writes a persistent local bookmark, Share updates the clipboard, and Connect can initiate a friend request; those effects were not triggered against the user's real profile during this visual pass. Therefore this is not evidence that every Build action was behaviorally exercised;
- Shell startup and popup inspection showed no visible Friends/Build error banner. Process log stream inspection via `quickshell -p /home/harshith/omarchy/shell log` confirms that `community.omarchy-friends` reloaded cleanly with zero QML warnings or runtime load errors. Source and installed active QML matched. A follow-up keyboard probe showed a cyan focus outline on the Friends Build navigation item, but Return went to the pre-existing terminal behind the popup (now at a sudo password prompt); no password was entered and no further UI input was sent. This probe does not validate Build opening or keyboard activation, and indicates the live focus handoff is not safely verified. The user has since unlocked normally; Stay Awake remains enabled because the configured idle lock delay is zero. The user's `shell.json` was not edited;
- an earlier shell hot-reload had reported `Could not attach Keys property ... is not an Item`. The handler was moved from the non-Item panel root onto focused QML Items, covered by a regression test, and passes installed-Omarchy qmllint. Current keyboard navigation reaches the Friends sections and Build tabs, but every action is not yet runtime-tested;
- V3 -> V2 -> legacy fallback runtime, valid desktop invite dispatch, and the remaining action-level interaction sweep are unverified. The valid invite dispatch can create an outgoing request/contact relays, so it was not dispatched from the user's real profile. URI-handler uninstall cleanup is a confirmed platform integration gap: the installed Omarchy plugin remover disables/removes the plugin directory and rescans, but does not invoke per-plugin cleanup; Friends' user-level desktop registration can therefore remain stale after removal. No Omarchy system-wide remover change was made. The candidate and installed checkout are still uncommitted.

## Public Beta limitations

- Private messaging has not had an independent external security audit.
- Public relay availability can vary, including intermittent relay timeouts or rejection.
- Exhaustive automated interaction testing of the native Omarchy layer-shell popup is limited.
- New profiles keep a generated pseudonymous handle discoverable while activity and profile-detail sharing is opt-in; previously saved explicit choices are preserved. See README for the public-relay retention caveat.

**Release posture: not yet cleared for all-user rollout.** Current source and installed checkout gates pass and isolated Build Network/private-message relay smoke evidence exists. A supported full shell restart and fresh Chats/Me popup checks now pass; the Me header copy fits. Help placeholders and Build need fresh post-restart visual confirmation; the keyboard focus outline did not prove that activation reached Friends, so popup keyboard activation remains unverified. QML warning-free status was not established, runtime V3 → V2 → legacy fallback and valid desktop invite dispatch remain unverified, and not every state-changing action was exercised against the user's live identity. Stay Awake remains enabled because the configured idle lock delay is zero; the user has since unlocked normally. Automatic cleanup of the URI association is unsupported by the current Omarchy plugin-removal path and needs an explicit platform-level decision. Do not merge `main` automatically.

## Stop condition

Do not reopen architecture or feature brainstorming for v4.15. Fix only reproduced release blockers. Do not merge `main` until Harshu explicitly asks for the merge.
