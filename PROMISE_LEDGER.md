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
- [x] Best-effort desktop URI registration is now performed idempotently by `build_network_app_v3.py` when Build Network starts.

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
- [x] Private follow-up routes through the existing Friends chat rather than putting sensitive debugging into public Build Network cards.

## Community memory

- [x] Solution Cards.
- [x] Worked / partial / did-not-work verification.
- [x] Environment labels on verification.
- [x] Help -> Solution conversion without retyping the original problem/environment.

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
- [x] CI compile + full unit suite + simple remote-exec grep boundary.

## UI

- [x] V3 liquid-glass Build Network panel.
- [x] Reusable `GlassSurface.qml` and `GlassPill.qml` primitives.
- [x] Discover / Build / Share-Test / Help / Community / Create surfaces.
- [x] Existing Friends UI and messaging engine left intact to minimize regressions.
- [x] One active Build Network UI path; obsolete V1/V2 panels removed.

## Deliberately separate security migration

- [ ] Existing private-message encryption has NOT been silently replaced in this feature branch.
- [ ] Migrate private DMs/groups to a standard audited Nostr private-message scheme (NIP-44 v2, and evaluate NIP-17/NIP-59 metadata protection) only with migration compatibility tests and real two-client validation.

This is deliberately separate because changing working private-message cryptography casually is more dangerous than leaving a clearly documented migration task.

## Distribution / adoption work

- [x] Install command remains documented.
- [x] Marketplace preparation notes exist in `docs/marketplace-issue.md`.
- [x] First-50 launch/metrics playbook is in `docs/launch-playbook.md`.
- [ ] Actual marketplace acceptance is external to this repository and requires the current marketplace review/submission process.
- [ ] Real-user liquidity cannot be coded; it requires seeding actual Omarchy users.

## Remaining before merge

These are validation tasks, not missing product architecture:

1. Run `omarchy plugin validate .` on the real Omarchy install.
2. Run `qmllint` against the actual Omarchy shell imports.
3. Open every V3 surface and repair clipping/wrapping/runtime API differences.
4. Two-instance relay sync test.
5. Verify URI opening through the user's desktop environment.
6. Regression-test existing DMs/groups/World/Circles/focus.
7. Decide and test the private-message crypto migration separately.

Do not add more product features before the real-system validation pass unless a real tester exposes a concrete missing workflow.
