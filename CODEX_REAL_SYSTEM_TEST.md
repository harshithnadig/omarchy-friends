# Codex final real-system release pass — Omarchy Friends v4.14

Branch: `feature/build-network`

This is **not** a build-from-scratch or feature-brainstorming task. Product architecture, signed Build Network objects, liquid-glass V3 UI, collaboration flows and release hardening are already implemented.

Read first:

1. `PROMISE_LEDGER.md`
2. `V3_UI_WIRING_MAP.md`
3. this file

Do not merge into `main` unless Harshu explicitly asks after all gates pass.

## 1. Checkout and establish a clean baseline

```bash
git fetch origin
git switch feature/build-network
git pull --ff-only
git status --short
git rev-parse --abbrev-ref HEAD
```

Confirm the branch is exactly `feature/build-network` and the worktree is clean before editing.

## 2. Fix the known version mismatch FIRST

`manifest.json` is v4.14.0. The live Friends engine currently still has:

```python
PLUGIN_VERSION = "4.12.0"
```

in `bin/omarchy-friends`.

Change that constant to:

```python
PLUGIN_VERSION = "4.14.0"
```

Do not modify protocol versions or capability names just to make numbers match.

## 3. Wire the already-implemented V3 actions into the glass UI

Follow `V3_UI_WIRING_MAP.md` exactly. Do not invent a competing backend.

Inside `BuildNetworkPanelV3.qml`, make these existing service actions reachable and visually consistent with `GlassSurface.qml` / `GlassPill.qml`:

- Help: Can Help / Pair / stop availability and helper matches.
- Share: individual Setup Component sharing.
- Build: explicit public GitHub snapshot and publish selected Project Activity.
- Help: solved Help -> Solution Card.
- Public cards: external Share text.
- Settings/diagnostics: optional invite URI repair action.

Also add or validate one obvious visible route from the normal Friends surface to Build Network so ordinary users are not expected to discover middle-click by accident. Keep middle-click working.

Do not redesign the main Friends app. Add the smallest coherent entry/action consistent with its existing UI.

## 4. Run the final release gate

```bash
bash scripts/release-gate.sh
```

It must finish without `FAIL`.

Then run explicitly:

```bash
python3 -m unittest discover -s tests -v

omarchy plugin validate .

qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml \
  Panel.qml \
  Service.qml \
  BuildNetworkPanelV3.qml \
  BuildNetworkService.qml \
  GlassSurface.qml \
  GlassPill.qml
```

Fix branch-specific errors and rerun until clean.

## 5. Load the real plugin

Reload/rescan using the normal Omarchy workflow.

Verify existing Friends first:

- left-click opens Friends;
- middle-click opens Build Network;
- right-click cycles status;
- the new visible Build Network route works;
- DMs still send/receive;
- friend requests still work;
- private groups still work;
- World still syncs;
- Circles still posts/receives;
- focus/co-working still works;
- block/report behavior still works;
- update status now reports 4.14.0 consistently.

## 6. Visual V3 check

Verify all six Build Network sections at normal laptop scale:

- Discover
- Build
- Share
- Help
- Community
- Create

Expected visual direction: modern dark liquid-glass, generous hierarchy, translucent surfaces, capsule actions, no clipped text and no old debug-panel stacking.

Check the newly wired actions too. Do not introduce an unsupported blur dependency. Native supported compositor blur is optional; visual stability is more important.

Capture screenshots after fixes.

## 7. Core product smoke test

Use disposable public titles prefixed `TEST —` because Build Network objects are relay-readable.

Exercise:

1. Idea -> interested -> Build Room.
2. Build Room -> join -> role/task doing/done -> testing -> shipped.
3. Public GitHub snapshot -> publish one selected activity card.
4. Setup Card -> Compare with mine -> verify no system change.
5. Share one individual Setup Component -> Save/Open source/Chat only; NO install.
6. Test Request -> Works / Found issue.
7. Help Request with safe environment + `what AI/I already tried`.
8. Can Help and Pair availability -> verify helper match -> let advertised time expire or simulate expiry and confirm it disappears.
9. Offer help -> private Friends chat handoff -> author Mark solved -> Help -> Solution.
10. Solution Worked / Partly verification.
11. Ship Log.
12. Update Pulse report and similar-environment aggregate.
13. Event Going/Interested RSVP.
14. Challenge join/team path.
15. External Share text copied from a public object.
16. Save/hide behavior.
17. Health action and URI registration diagnostics.

## 8. Offline/retry validation

The release runtime now queues relay-failed public objects.

Test with Build Network relays unavailable:

1. create a disposable Idea or Help card;
2. confirm UI says it was saved locally for retry;
3. inspect `python3 bin/build_network_app_v4.py health` and confirm `pending_publish > 0`;
4. restore relay access;
5. Sync;
6. confirm queued object publishes and `pending_publish` returns to 0;
7. confirm no duplicate logical object is created.

## 9. Block-list integration

With user B visible in Build Network:

1. block B using the existing Friends block control;
2. refresh Build Network;
3. B's public Build Network cards/helper availability must disappear locally;
4. blocking must never be bypassed by Build Network.

## 10. Two-instance relay test

Use two real Omarchy installations or isolated state homes.

Verify A <-> B propagation for:

- Idea + interest;
- Build Room + join + task update;
- Setup + component;
- test request/result;
- Help + offer + helper availability;
- Solution verification;
- RSVP/challenge join;
- Project Activity;
- newer replacement of the same authored object;
- duplicate copies from multiple relays collapse correctly;
- blocked builder filtering remains local and reliable.

## 11. Invite URI

Run:

```bash
xdg-mime query default x-scheme-handler/omarchy-friends
```

Then click/open a real disposable:

```text
omarchy-friends://invite/<public-key>
```

Confirm the registered handler uses the installed plugin path, rejects every unsupported URI shape, and does not hard-code a developer checkout.

## 12. Security regression

Confirm:

- unsigned/invalid Build events are rejected;
- unknown object types fail closed;
- `file://`, `javascript:` and control-character URLs are rejected;
- public Build objects contain no Friends private key;
- shared setup metadata cannot execute shell/install commands;
- remote text is display data, never evaluated;
- safe environment collection contains no hostname, username, IP, serial or file contents;
- corrupt Build state is quarantined and a fresh schema-2 state is created;
- state/backup files containing identity material are user-only where practical.

## 13. Private-message crypto is NOT part of this coding pass

Do not casually rewrite DM/group encryption while validating this release.

Read `docs/private-messaging-security-migration.md` and report whether v4.14 should:

A. ship with current private messaging explicitly documented as application-specific and unaudited, then migrate in a dedicated release; or
B. be held until the separately tested NIP-44 migration is complete.

Do not make stronger security claims than the implementation supports.

## 14. Final report

Return only:

1. failures found;
2. files changed;
3. exact release-gate/unit/qmllint/plugin-validation results;
4. screenshots of all six Build Network sections plus the visible entry from Friends;
5. two-instance relay results;
6. offline retry result;
7. block-list integration result;
8. URI result;
9. regression result for existing Friends;
10. private-message crypto release recommendation;
11. one final verdict: `READY TO MERGE` or `NOT READY`, with concrete blockers only.

Commit and push fixes only to `feature/build-network`. Do not merge `main`.
