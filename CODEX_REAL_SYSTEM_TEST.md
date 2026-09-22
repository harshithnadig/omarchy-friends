# Codex real-system validation — Omarchy Friends v4.14

Branch: `feature/build-network`

This is **not** a build-from-scratch task. The Build Network backend, federation, final collaboration primitives and liquid-glass V3 UI are already implemented. Read `PROMISE_LEDGER.md` first. Your job is only to validate/fix real Omarchy integration issues that cannot be proven from GitHub CI.

Do not merge into `main` unless Harshu explicitly asks.

## 1. Checkout

```bash
git fetch origin
git switch feature/build-network
git pull --ff-only
git status --short
git rev-parse --abbrev-ref HEAD
```

Confirm the branch is exactly `feature/build-network`.

## 2. Fast automated pass

```bash
python3 -m py_compile \
  bin/build_network.py \
  bin/build_network_social.py \
  bin/build_network_v2.py \
  bin/build_network_v3.py \
  bin/build_network_runtime.py \
  bin/build_network_app_v2.py \
  bin/build_network_app_v3.py \
  bin/omarchy-friends-open

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

If QML/plugin validation exposes branch-specific errors, fix them directly on this branch and rerun the full commands. Do not redesign the product unless a real API incompatibility forces a small change.

## 3. Load the real plugin

Reload Omarchy shell/plugin using the normal local workflow.

Verify existing Friends first:

- left-click opens normal Friends;
- right-click cycles status;
- DMs, groups, World, Circles, focus and profile still function;
- no new warnings/crashes from the Build Network service.

Then middle-click Friends and verify the V3 Build Network opens.

## 4. Visual V3 check

The expected direction is a modern dark liquid-glass surface, not the old flat debug-panel look.

Check:

- hero glass surface and subtle accent glow;
- segmented floating tabs;
- larger spacing/hierarchy;
- rounded glass content surfaces;
- capsule actions;
- no clipped text or action wrapping at normal laptop scale;
- scroll behavior remains smooth;
- inputs are readable with the current Omarchy theme;
- selected/hover states remain visible in dark/light-compatible color tokens.

If the real shell exposes a stable native blur effect, use it **only if** it is already part of supported Omarchy/Quickshell APIs. Do not add an experimental dependency just to chase literal blur.

Capture screenshots of Discover, Build, Share, Help, Community and Create after fixes.

## 5. Core Build Network smoke test

Use disposable titles prefixed `TEST —` because public objects are relay-readable.

Exercise:

1. Idea -> interested -> Start build.
2. Build Room -> join -> task doing/done -> owner testing/shipped state.
3. Setup Card -> Compare with mine -> verify no machine changes occur -> Copy recipe.
4. Share one individual Setup Component (for example a theme/plugin/bar) -> verify it is metadata + HTTP(S) URL only.
5. Test Request -> Works / Found issue using safe environment labels.
6. Help Request -> Offer help -> Friends private-chat handoff -> author Mark solved.
7. Set `Can Help` availability with skills and verify a compatible Help Request receives a helper match.
8. Set `Pair` availability and verify it appears in the pairing data returned by status.
9. Convert a solved Help Request into a Solution Card without retyping the original problem/environment.
10. Solution -> Worked / Partly verification count.
11. Ship entry.
12. Update Pulse report -> confirm similar-environment aggregate appears when labels overlap.
13. Event -> Going/Interested RSVP.
14. Challenge -> Join -> Start a team/Build Room.
15. Save/hide local object behavior.
16. For a public GitHub repository, run the GitHub snapshot helper and verify it returns only recent public commits/open PRs/open issues; then publish one selected Project Activity card.
17. Generate external share text for one public object.

Useful CLI probes:

```bash
python3 bin/build_network_app_v3.py status | python3 -m json.tool
python3 bin/build_network_app_v3.py inspect-environment | python3 -m json.tool
python3 bin/build_network_app_v3.py register-uri | python3 -m json.tool
```

## 6. Two-instance relay test

With two Omarchy installations or isolated state homes:

- A creates Idea; B receives it after Sync.
- B marks interested; A count increases.
- A opens Build Room; B joins; A sees join.
- B task update appears to A.
- A Setup Card and Setup Component appear on B; Compare performs only local metadata comparison.
- A advertises Can Help/Pair availability; B receives it and compatible Help Requests show the match.
- Project Activity cards propagate.
- Test result, help offer, solution verification, RSVP and challenge join all propagate.
- multi-relay duplicate copies collapse to one logical object.
- newer event for the same author/object wins.

## 7. Security regression

Confirm:

- unsigned/invalid events are rejected;
- unknown object types fail closed;
- `file://`, `javascript:` and control-character URLs do not become openable links;
- public relay objects never contain the Friends private key;
- shared setup/component metadata cannot execute shell/install commands;
- remote text is displayed as text, never evaluated;
- safe environment collection contains no hostname, username, IP, serial or file contents;
- public GitHub snapshot accepts only HTTPS `github.com/owner/repo` URLs and does not use credentials/tokens;
- `omarchy-friends://invite/<pubkey>` handler rejects every other URL shape;
- Build state remains user-only where practical;
- existing block/report/friend controls are not bypassed.

## 8. Invite desktop registration

`build_network_app_v3.py` now creates an idempotent user-local `omarchy-friends.desktop` entry and asks `xdg-mime` to register `x-scheme-handler/omarchy-friends` when the Build service first starts.

Validate on the actual installed plugin path:

```bash
xdg-mime query default x-scheme-handler/omarchy-friends
```

Then click/open a disposable `omarchy-friends://invite/<64-hex-pubkey>` link. Verify it reaches the safe `bin/omarchy-friends-open` parser. If the desktop environment requires a different supported registration mechanism, make the smallest local-path-safe correction. Do not hard-code a developer checkout path.

## 9. What NOT to build in this pass

Do not spend quota inventing features. Specifically do not:

- rewrite Build Network architecture;
- auto-install setup cards/components;
- add remote shell execution;
- upload configs/logs/files automatically;
- replace the existing private-message crypto during this validation pass;
- rebuild V1/V2 panels (they were intentionally removed).

The private-message standardization work has its own gate in `docs/private-messaging-security-migration.md`.

## 10. Final report

Return only:

- failures found;
- files changed to fix them;
- exact test results;
- screenshots of the six V3 tabs;
- two-instance relay result;
- helper/pair matching result;
- GitHub snapshot/project-activity result;
- URI registration result;
- security/privacy findings;
- whether this branch is stable enough for a second real Omarchy user.

Commit and push fixes only to `feature/build-network`. Do not merge `main`.
