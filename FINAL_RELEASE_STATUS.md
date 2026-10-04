# Omarchy Friends v4.18.0 — release candidate status

## v4.18.0 current candidate (2026-10-04)

- Adds direct-chat typing indicators for connected, compatible Friends peers.
  The state is end-to-end encrypted, sent in NIP-59 ephemeral kind-21059
  envelopes, rate-limited, replay-filtered, and kept only in a 12-second
  owner-only runtime cache. It never enters chat history or notifications.
  Users can disable sharing in Me → Privacy; groups and old clients are not
  included.
- New profiles remain discoverable in World by default. Existing saved choices,
  including explicit hidden profiles, are preserved. The candidate does not
  touch local chat journals or migration data.
- World refresh now queries configured relays concurrently with a shared
  five-second deadline instead of serially waiting on each relay. Duplicate
  relay URLs are removed from the configured set. A synchronization test
  confirms all relay requests overlap; fresh-profile default discovery and
  preservation of an existing hidden choice are also covered.
- The release gate passes all 335 tests, including localhost NIP-17 direct and
  group relay round trips. Python compilation, remote-execution checks, and
  health check pass. Omarchy plugin validation and QML lint were not rerun in
  this environment; their previous candidate results do not verify this turn's
  live UI behavior.
- Rendered UI, live public relay interoperability, and an actual two-user
  typing exchange have not been verified. Candidate is on
  `fix/accurate-world-status` and draft PR #8; it has not been installed or
  published to the marketplace and is not release-cleared.

## v4.17.0 historical candidate (2026-10-04; superseded by v4.18.0)

- World now distinguishes checking, failed/stale relay status, and a healthy
  relay check with no other fresh presences. Its empty state explains that
  visibility controls whether others can find you, not whether you can discover
  other users. It never fabricates people.
- The profile's green online dot now requires a recent relay-confirmed presence
  publish and a fresh, healthy relay check. Background listener socket sends
  no longer count as confirmed publishes.
- Shared surfaces and controls use flatter fills, quieter borders, and a
  readable sans-serif font. This affects Friends and Build Network, including
  compatibility panels.
- Chat storage is unchanged. Existing saved privacy choices are preserved;
  only the default applied to new profiles or profiles with no saved World
  choice changes.
- Saved conversations remain discoverable through the full durable local index,
  and the desktop file chooser now launches only after the full-screen Friends
  overlay releases focus. The panel reopens after choosing or cancelling.
- New profiles publish a minimal pseudonymous World presence by default while
  online. Existing saved visibility choices, including hidden profiles, remain
  unchanged on upgrade; users can turn World visibility off at any time.
- The CI release gate passed all 327 tests; `qmllint` passed against the
  installed Omarchy shell imports. CUA exposed no desktop window for rendered UI
  verification, so the visual result and live World/relay behavior remain
  unverified. The candidate is on `fix/accurate-world-status` and draft PR #8;
  it has not been installed or published to the marketplace and is not
  release-cleared.

## v4.16.1 hotfix

The v4.16.1 hotfix forces Friends QML labels and editable text areas to plain
text so peer-controlled messages and profile fields cannot initiate remote
image requests through Qt's automatic text detection. It does not change chat
storage. Marketplace review remains tied to the exact published commit and is
not complete until its automation and maintainer review finish.

The historical v4.16.0 and v4.15.1 sections are retained below for provenance.

## Historical v4.16.0 candidate state (2026-09-29; superseded by v4.17.0)

- **Current audit follow-up (2026-09-29):** reproduced why users saw the V2 compatibility screen: Friends V3 put a nonvisual `Connections` object directly in `KeyboardPanel`'s `contentItem` list, causing Loader.Error. Moved it under an invisible `Item` and added a regression test. Removed the obsolete optional-link composer field from V3, keeping link sharing through the attachment menu/message field. The local journal was read without mutation: it still has 88 rows, including 80 NeonOtter messages and eight unlinked recovery messages; `conversation-history` returns all 80 for NeonOtter. The fixed installed panel was opened and visually verified: V3 Chats lists NeonOtter, Recovered messages and CosmicFox, the selected NeonOtter transcript renders, and the composer shows only its attachment icon, message field and Send button. The change passes `qmllint` and the targeted UI contract suite. Actual file selection/send and two-device exchanges remain unverified. Marketplace compatibility validation passes at exact commit `36c45ac`, but publication is not complete and the security baseline requires maintainer review.
- Chat-pane overflow root cause fixed: the message scroller used the left chat-list header height instead of the conversation header height, so the composer could extend into the bottom footer. It now subtracts the correct conversation-header height and lets the scroller shrink to the remaining space. The chat header is compact again, with Focus and More beside the avatar and the per-chat Build action removed. Removed an unsupported `Text.selectByMouse` property that caused Friends V3 to fall back to V2. The supported shell restart and plugin rescan produced no Friends V3 load/fallback warning; source and installed QML match. A fresh live open restored NeonOtter-8176 and CosmicFox-2449 with saved history after a status-load race fix.
- The attachment menu is parented to the persistent chat content `Item` and positioned in that item's coordinate space; its prior `KeyboardPanel` parent generated live Quickshell conversion/type warnings. The in-panel `QtQuick.Dialogs` picker was replaced on 2026-09-29 after the user reported that choosing a file or folder produced no visible chooser. Friends now invokes `org.freedesktop.portal.FileChooser.OpenFile` through the desktop session bus; directory mode is used for folders. The layer-shell panel is suspended while the portal's separate window is active, then restored on selection or cancellation. The request callback is matched to its portal request path and only local `file://` URIs are accepted. Portal FileChooser version 4 and its GTK/Hyprland services are present on this machine. Four focused mocked-DBus tests cover file/folder mode, response-path filtering, cancellation, and local URI validation. Two recipient-side regressions additionally confirm that tampered ciphertext fails AES-GCM authentication, oversized download bodies are rejected, and temporary download files are removed after either failure. A live journal audit then exposed recurring Circle-view QML binding-loop warnings in a previously loaded component. V3 now snapshots the latest 80 Circle messages when the service array changes and sizes message bubbles from `TextMetrics`, removing the self-referential implicit-width binding. The installed QML triggered Omarchy's plugin watcher; the Quickshell PID stayed unchanged, the Friends listener and daemon returned as one process each, and no matching Circle binding warnings appeared for 37 seconds after reload. The Circle page still needs visible interaction verification. The current chooser has not been visually verified: CUA exposed no native apps in this run, so no dialog was opened over the user's active fullscreen window. Earlier visual confirmation referred to the superseded Qt-dialog path and does not prove this portal implementation. The compositor confirmed that assigning a namespace in the Friends subclass alone did not override `KeyboardPanel`'s hard-coded `omarchy-keyboard-panel` namespace, so the base popup now exposes a configurable `layerNamespace`, with Friends opting into `omarchy-friends`. CUA foreground/cancellation confirmation applied to the superseded Qt-dialog version only; it does not verify the current portal chooser. The Friends card background is unblurred by its layer rule. A narrow user-owned Hyprland exception now disables blur and opacity for the exact file/folder dialog titles; its post-reload appearance has not yet been visually rechecked. No generated Glass Tuner config was edited. Source and installed Friends QML match; QML lint passes. The service now declares Omarchy's injected `shell` and `manifest` properties, but the current plugin watcher reload produced no new initial-property assignment warning in the inspected journal interval; a visible panel open is still required to verify UI injection.
- The compatibility `status` command still includes full message history. Friends V3 now uses `status-ui`, which returns one latest-message preview per conversation from an encrypted, HMAC-keyed journal index, then fetches the selected thread through validated chronological `conversation-history` pages of 80 messages. The first index build scans the journal once; steady-state status decrypts one preview per thread, and history reads only the selected thread. Search still scans/decrypts the local journal. The eight-second UI status poll runs only while Friends or Build is open. Relay listening, event polling, and queued-message retries remain active while the UI is hidden.
- Chat UI builds a cached per-conversation message index from previews and the loaded thread page. `search-messages` searches saved local history and returns the latest matching message per conversation; opening a result fetches the page containing it. Older pages load on demand and preserve the current scroll anchor. Compatibility history paging now includes older direct-message records whose `conversation_key` is empty by matching their stored peer key. Focused tests cover summary compaction, page scope/bounds, keyless legacy records, local search, and the QML service contract.
- Candidate changes include encrypted local message journaling, optimistic send bubbles with failure retention, encrypted file/folder attachments, large-file transfer through a user-configured HTTPS Blossom server, threaded replies, emoji reactions, encrypted “delete for everyone” with bounded handling for relay reordering, a single attachment icon with file/folder/link choices, per-conversation unread counts with device-local cursors, local message search, encrypted device-local pinned and muted conversations, and LAN presence disabled by default on new profiles.
- Chat history renders in 80-message pages to bound QML delegate work; an explicit Load earlier messages action pages backward while preserving the viewport, and search can open the page containing an older match.
- A current local journal audit found 88 encrypted message rows: 80 linked to NeonOtter-8176 and eight older outgoing rows with the local account key but no recipient. The latter are exposed as a read-only “Recovered messages” archive and are not attributed to a friend. The CosmicFox-2449 friendship and one-DM memory counter remain, but no corresponding message is present in the current journal or available local backups; that old message could not be recovered. The additive index migration preserved all 88 message rows. Installed status/history commands return the 80 linked messages and all eight archive messages. The live rendered panel was not verified in this turn; QuickShell was left running without a restart.
- Direct and group send results now return the exact saved message event ID, including delivery failures and partially delivered groups. Friends V3 reconciles optimistic bubbles against local history by that ID in every send state, so relay-echo timing and retryable sends do not leave duplicate bubbles. The release gate covers the CLI response contract and failed/partial-send reconciliation. The earlier Qt chooser's foreground/cancel behavior was confirmed through CUA, but the current portal chooser's foreground/cancel behavior, selected-file transfer, and two-device exchange remain unverified.
- Delivery status copy now distinguishes “Sent · relay” from recipient read receipts and uses separate unconfirmed/partial group states; CLI send results return that exact persisted status. README privacy guidance now correctly separates device-local unread cursors from optional encrypted peer read receipts.
- Failed private messages now retry automatically one at a time with 5-second, 15-second, 60-second, and 5-minute backoff, capped at four automatic attempts; manual retry remains available after the cap. Retries reuse the saved authenticated payload and event ID, group retry actions include only unconfirmed members, prior failures without retry metadata are upgraded into the queue, and stale “Sending…” records recover after 30 seconds.
- Message bubbles now show a single accessible three-dot menu instead of always-visible reaction, reply, and delete controls. The popup contains all seven supported reaction choices, Reply, Delete for me, and the author-checked Delete for everyone action. Delete for me is device-local, stored as an encrypted tombstone, and prunes the message row from the encrypted journal; it does not publish a relay event.
- Text messages and shared links can be forwarded to an existing friend or private group from the three-dot menu. The picker states that it forwards text/links but not attached files or the original sender, adds a visible “Forwarded:” prefix to text, and requires a separate Forward click; the resulting message uses the existing encrypted direct/group send path.
- Sent text-only direct and group messages can now be edited for 15 minutes. Edits are encrypted and author-checked; only current Friends clients apply this envelope extension, while older clients retain the original message. The popup exposes Edit only for eligible messages, and the composer provides Save and Cancel.
- Read receipts are now an explicit Me → Privacy opt-in and remain off by default. Compatible Friends peers receive encrypted receipts on opening a chat; direct receipts are addressed to the friend and group receipts to current group members. Failed receipt publication stays eligible for retry. Unrelated NIP-17 clients may render the receipt as a short ordinary message.
- Direct chat's More menu now offers a pairwise safety code: a domain-separated SHA-256 fingerprint of both account public keys, independent of key order. The UI tells users to compare it through another trusted channel and states that it neither authenticates a real-world identity on its own nor provides forward secrecy.
- The current source gate passes **306 tests**. New coverage includes encrypted NIP-17 and legacy direct edits, out-of-order edit delivery across restart, group editing, forged-author/attachment/expired-window rejection, read-receipt consent/default, encrypted direct and group receipt application, retry/dedupe, edited-state persistence, bounded friend/group CLI history paging, cached per-conversation UI indexing, accessible 80-message history paging with scroll-anchor preservation, search jumps into older pages, read-only recovery for unlinked local messages, action-menu/privacy UI contracts, forwarding through existing encrypted send methods, in-window file/folder picker wiring, folder paths and filenames with spaces through encrypted ZIP send and recipient save, attachment symbolic-link handling including rejection during large-file encryption, Blossom upload rejection for failed/private/mixed DNS answers, public-IP pinning with original-hostname TLS verification, and rejection of private/reserved/transition IPv6 ranges; it also covers pairwise safety-code derivation/CLI/UI disclosure, localhost WebSocket direct inbox discovery/delivery/decryption/dedupe, three-account encrypted group-invite/message delivery with outer-event privacy checks, Quickshell worker shutdown on supervisor exit or PID reuse, the real-machine Friends/Omarchy popup namespace contract, the service host-injection contract, and chat selection after asynchronous status refresh. Validation covers source release checks, manifest/runtime version agreement, `omarchy plugin validate`, and Omarchy-import `qmllint`.
- The forward-secrecy migration gate is documented in `docs/private-messaging-security-migration.md`: keep NIP-17/legacy adapters, evaluate a pinned session protocol, and require exact-version security review plus direct/group interop and migration tests before negotiating it. NIP-44 still provides no forward secrecy.
- Large-file Blossom upload and download now resolve the target before opening a connection, reject DNS failures or any private/reserved/non-unicast/transition-address answer (including mixed public/private sets), and pin the HTTPS socket to a validated public IP while preserving original-hostname TLS verification. Regressions cover DNS failure, private/mixed/NAT64 answers, validated-IP socket routing, TLS hostname preservation, encryption upload and authenticated download.
- Local search covers message and reply text, media URLs, and attachment names; it skips deleted messages, keeps its query/index in app memory, and jumps to the latest matching message in each conversation.
- The preceding 236-test gate covered local-search, pin, and mute UI contracts; encrypted local pin persistence/bounds and mute persistence; notification suppression while preserving unread state; LAN-presence default-off and explicit-opt-in/migration coverage; modern and legacy deletion; group scoping; unauthorized deletion attempts; relay reordering; standard NIP-17 file-message interoperability; selectable-socket inbox readiness; the coarse background World-sync cadence; and unread migration/persistence/concurrency.
- The persistent private inbox listener now blocks on all ready relay sockets rather than polling each relay every 150 ms; it refreshes external state at most every 30 seconds and reloads immediately before mutating on an incoming event. Presence and reconnect deadlines remain bounded. Background World relay polling is now every 60 seconds; explicit refresh remains immediate. These changes reduce idle work; long-duration CPU/thermal measurements have not been repeated.
- The installed plugin matches the candidate for `FriendsPanelV3.qml`, `Service.qml`, and `bin/omarchy-friends`. The attachment chooser uses parentless Qt Quick system file/folder dialogs; foreground behavior and cancellation were confirmed live. A targeted no-blur/opacity override was added to the user-owned Hyprland config for the exact chooser titles, but that visual result is not yet rechecked. Attachment reads open regular files with no-follow/nonblocking flags; folder ZIP preparation and large-file upload use the same guarded file-open path. `qmllint` passes; the live Quickshell log confirms plugin reload. Lifecycle inspection reproduced two stale listener/daemon workers orphaned by a prior shell restart; the engine now snapshots the Quickshell parent's PID and `/proc` start time and exits when that exact supervisor disappears or its PID is reused. A post-fix supported shell restart left one listener and one daemon owned by the new Quickshell PID; the two pre-fix orphan PIDs were stopped explicitly. This is a process-lifecycle check, not a long-duration CPU/thermal measurement.
- Local Radar uses unauthenticated UDP broadcast, so new profiles now default `share_lan` to false. Existing saved choices remain intact; regression tests cover default-off, no transmission before opt-in, explicit opt-in, and migration preservation.
- Pinned direct/group conversations are device-local, stored in the encrypted state, validated against current friendship/group membership, and bounded to 20. The regression suite covers persistence, sorting contracts, unpinning, invalid conversations, and the cap.
- Muted direct/group conversations suppress new chat toast/notification events on this device while retaining messages and unread counts. Mute settings use the encrypted local state and do not change network messages; the 236-test gate covers direct-message notification behavior and mute persistence for direct/group chats.
- Reply/reaction/deletion protocol handling and composer/menu UI contracts have unit coverage. Direct and three-account group message flows are exercised over real localhost WebSockets. CUA confirmed the system picker foreground and cancellation path. Real two-device attachment/reaction/deletion exchange, post-config picker appearance, long-duration CPU/thermal behavior, legacy-client behavior, and independent security review remain unverified.
- Private messaging still does not provide forward secrecy, persisted or independently verified device identities, remote read receipts, typing indicators, voice/video calls, or account/key recovery. The pairwise safety code only helps detect a key mismatch when both people compare it through a separate trusted channel. Unread cursors stay encrypted on this device and are never sent to a relay. Deletion is best effort and cannot guarantee erasure of copies another client or relay already retained. Do not describe this implementation as audited or equivalent to WhatsApp's security guarantees.

The v4.16.0 candidate extended the historical v4.15.1 scope. This is a retained snapshot, not the active candidate status; current status is recorded at the top of this file.

**Historical release posture:** Omarchy Friends v4.16.0 was not release-cleared. Direct and group messaging passed isolated localhost WebSocket round trips. At that time, actual file selection/send and two-device exchanges were unverified. See the v4.17.0 status at the top for current candidate evidence and remaining gates.

## Repository-side state

- Product architecture: the planned v4.15 scope was implemented; this does not mean current release gates are complete.
- Build Network backend: complete.
- Friends V3 is the preferred shell; Friends V2 is the compatibility fallback; `Panel.qml` is the final legacy fallback.
- Build Network uses `BuildNetworkPanelV3.qml -> BuildNetworkService.qml -> bin/build_network_app_v4.py` and is now **lazy-loaded only when opened** so normal Friends use does not start its Python/network work unnecessarily.
- Historical v4.16.0 manifest/install state is retained here for provenance. The active candidate version and publication state are defined in the v4.17.0 status at the top.
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

The preceding v4.15.1 local working-tree record had parent `923a40a37e8f7a6535f9db55c54ea4236e575201` plus uncommitted changes:

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

**Release posture: not yet cleared for all-user rollout.** The current source and installed checkout pass the automated release gate, plugin validation and QML lint. The 2026-09-29 sampled journal interval after the Friends panel reload contains no new Friends QML warnings, but this audit could not visually verify rendered chats or the current portal picker. Real two-device attachment/action behavior, runtime V3 → V2 → legacy fallback, valid desktop invite dispatch, and the full live interaction sweep remain unverified. Independent security review remains outstanding; do not describe the cryptography as audited. The candidate is not a marketplace release until exact-commit validation and maintainer publication complete; the live UI and two-device gates remain unresolved.

## Stop condition

Do not reopen architecture or feature brainstorming for v4.15. Fix only reproduced release blockers. Do not merge `main` until Harshu explicitly asks for the merge.
