# Omarchy Friends v4.14 — promise ledger

This file is the source of truth for the product ideas discussed while designing the Build Network. It exists so future agents do not re-invent features or claim something is missing when it is already implemented.

## Human layer / messaging

- [x] Public Omarchy World presence.
- [x] Private friend requests and encrypted DMs through the existing Friends engine.
- [x] Private groups.
- [x] Public Circles/community chat.
- [x] Focus/co-working ritual.
- [x] Waves / lightweight social signals.
- [x] Direct invite links.
- [x] `omarchy-friends://` parser.
- [x] Best-effort desktop URI registration is performed idempotently by the Build Network runtime using the actual installed handler path.

## Discover / social creation loop

- [x] Discover feed for useful community work rather than a generic engagement feed.
- [x] Idea cards.
- [x] Interest signals.
- [x] Idea -> Build Room.
- [x] Ship Log.
- [x] Contribution-oriented reputation (builds/tests/solutions/help/tasks) instead of follower counts.
- [x] External share-text generator for Ideas, Builds, Setups, Ships, Help, Solutions, Events, Challenges and Project Activity.

## Build together

- [x] Build Rooms.
- [x] Roles needed.
- [x] Join Build Room.
- [x] Build task status: todo / doing / done / blocked.
- [x] Build lifecycle: building / testing / shipped / archived.
- [x] GitHub repository links.
- [x] Project activity cards for commits, PRs, issues, releases and discussions.
- [x] Explicit public-GitHub snapshot helper for recent commits/open PRs/open issues. It accepts only `https://github.com/owner/repo` and never uses credentials.
- [x] Challenge -> team/build path.

GitHub remains the source of truth for code and issue history. Friends is the human coordination/discovery layer.

## Help / Can Help / Pair

- [x] Human Help request.
- [x] Short `what I / my AI already tried` context.
- [x] Safe explicit environment labels: Omarchy version, architecture, GPU vendor and kernel version only.
- [x] Help offers.
- [x] Close/solve help requests.
- [x] `Can Help`, `Pair`, and `Building` availability objects.
- [x] Skill + environment matching for help requests.
- [x] Matching excludes the request author and does not use follower/popularity scores.
- [x] Release hardening automatically expires stale availability after its advertised time window.
- [x] Private follow-up routes through the existing Friends chat rather than putting sensitive debugging into public Build Network cards.

## Community memory

- [x] Solution Cards.
- [x] Worked / partial / did-not-work verification.
- [x] Environment labels on verification.
- [x] Help -> Solution conversion without retyping the original problem/environment.
- [x] Release runtime extends the relay lookback for durable knowledge instead of treating solutions like a short-lived live feed.

A fully automatic AI summary of private chats is intentionally not published without user review. Private conversation should never silently become public community memory.

## Share setups

- [x] Setup Cards.
- [x] Safe shallow local setup inspection (theme, plugin directory names, architecture/OS, shell, terminal, editor).
- [x] Setup compare/review plan showing missing/already-present/local-only plugins plus field differences.
- [x] Individual Setup Component cards: theme, plugin, bar, wallpaper, font, terminal, editor, shell, keybindings or other.
- [x] HTTP(S)-only component/dotfile source links.
- [x] Copy/review workflow.
- [ ] Automatic apply/install is intentionally NOT implemented. Remote community data must never silently become shell commands or overwrite dotfiles.

## Test network

- [x] Test requests.
- [x] Requested hardware/environment tags.
- [x] Signed pass/issue test results.
- [x] Environment-aware result context.

## Omarchy Update Pulse

- [x] Explicit opt-in update reports: working / minor issue / rolled back.
- [x] Overall aggregate.
- [x] Similar-environment aggregate using safe tags.
- [x] No hidden telemetry.

## Events / community rituals

- [x] Meetup/online event cards.
- [x] Going / Interested RSVP.
- [x] Build challenges.
- [x] Challenge joins/team metadata.
- [x] Existing Ship-It Friday/focus community rituals remain in Friends.

## Safety / abuse boundaries

- [x] Signed Nostr Build Network objects.
- [x] Unknown object types fail closed.
- [x] Bounded text/list/object sizes.
- [x] HTTP(S)-only shared URLs.
- [x] `file://` / `javascript:` URLs rejected from public collaboration objects.
- [x] No arbitrary remote command execution.
- [x] No config auto-install.
- [x] No arbitrary file upload.
- [x] Local hide/save controls.
- [x] Existing Friends report/block controls stay in the private/social engine.
- [x] Release runtime also filters public Build Network content from public keys already blocked in Friends.
- [x] Failed Build Network publishes are queued locally and retried on later sync.
- [x] Corrupt Build Network state is quarantined instead of silently destroying the only copy.
- [x] Build Network state has an explicit schema migration/backup path.
- [x] CI compile + full unit suite + remote-exec boundary + static release gate.
- [x] Release health command reports state schema, queued publishes, filtered blocks and relay health.

## UI

- [x] V3 liquid-glass Build Network panel.
- [x] Reusable `GlassSurface.qml` and `GlassPill.qml` primitives.
- [x] Discover / Build / Share-Test / Help / Community / Create surfaces.
- [x] Existing Friends UI and messaging engine left intact to minimize regressions.
- [x] One active Build Network UI path; obsolete V1/V2 panels removed.
- [ ] Final placement of the newest V3 service actions still needs to be wired into `BuildNetworkPanelV3.qml`: Can Help/Pair, individual Setup Component share, GitHub snapshot/activity publish, Help -> Solution, external Share, and optional URI-repair control. The backend/service API is already implemented; use `V3_UI_WIRING_MAP.md` without inventing another architecture.
- [ ] Build Network is currently primarily discovered through middle-click. A visible in-deck entry should be validated on the real UI so the flagship surface is not hidden from ordinary mouse users.

## Deliberately separate security migration

- [ ] Existing private-message encryption has NOT been silently replaced in this feature branch.
- [ ] Migrate private DMs/groups to a standard audited Nostr private-message scheme (NIP-44 v2, and evaluate NIP-17/NIP-59 metadata protection) only with migration compatibility tests and real two-client validation.

This is deliberately separate because changing working private-message cryptography casually is more dangerous than leaving a clearly documented migration task. Until that work is complete, do not describe the current private-message implementation as formally audited cryptography.

## Distribution / adoption work

- [x] Install command remains documented.
- [x] Marketplace preparation notes exist in `docs/marketplace-issue.md`.
- [x] First-50 launch/metrics playbook is in `docs/launch-playbook.md`.
- [ ] Actual marketplace acceptance is external to this repository and requires the current marketplace review/submission process.
- [ ] Real-user liquidity cannot be coded; it requires seeding actual Omarchy users.

## Release-hardening runtime

The final Build Network service path is:

`BarWidget.qml -> BuildNetworkPanelV3.qml -> BuildNetworkService.qml -> bin/build_network_app_v4.py`

`build_network_app_v4.py` adds release engineering rather than new social features:

- short-lived helper availability;
- reuse of the Friends block list;
- durable retry queue for relay-failed public posts;
- corrupt-state quarantine and schema migration backup;
- longer bounded knowledge lookback;
- release/health diagnostics.

## TRUE blockers before calling v4.14 stable

These are the remaining release gates, not invitations to brainstorm more features:

1. **Version consistency:** `manifest.json` is `4.14.0`, while the main `bin/omarchy-friends` engine still advertises `PLUGIN_VERSION = "4.12.0"`. Update the engine constant to `4.14.0` and rerun the release gate.
2. **Final V3 UI reachability:** wire the already-implemented newest service actions according to `V3_UI_WIRING_MAP.md`.
3. **Discoverability:** validate a visible, obvious route to Build Network in the real Friends UI instead of relying only on middle-click knowledge.
4. **Real Omarchy gate:** run `omarchy plugin validate .` and `qmllint` against the installed shell imports and fix any runtime/layout incompatibilities.
5. **Two-client validation:** test publish/receive/update/dedupe, offline retry and helper expiry with two isolated installs/state homes.
6. **Regression:** DMs, groups, World, Circles, focus, block/report and normal update flow must still work.
7. **Invite URI:** verify an actual `omarchy-friends://invite/...` click opens correctly from the installed plugin path.
8. **Private-message security decision:** either complete the standardized crypto migration with compatibility tests before making stronger security claims, or release v4.14 with the existing implementation explicitly described as application-specific and unaudited.

The Python CI being green is necessary but not sufficient. Do not merge solely because CI passes. Once the eight gates above are closed, stop adding features and cut the stable release.
