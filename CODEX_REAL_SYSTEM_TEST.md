# Codex real-system validation — Omarchy Friends v4.14

Branch: `feature/build-network`

This is **not** a build-from-scratch task. The Build Network backend, federation, advanced participation flows and liquid-glass V3 UI are already implemented. Your job is only to validate/fix real Omarchy integration issues that cannot be proven from GitHub CI.

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
  bin/build_network_runtime.py \
  bin/build_network_app_v2.py \
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

If the real shell exposes a stable native blur effect, you may use it **only if** it is already part of supported Omarchy/Quickshell APIs. Do not add an experimental dependency just to chase literal blur. The current design deliberately uses translucent layered glass that is safe without compositor blur.

Capture screenshots of Discover, Build, Share, Help, Community and Create after fixes.

## 5. Core Build Network smoke test

Use disposable titles prefixed `TEST —` because public objects are relay-readable.

Exercise:

1. Idea -> interested -> Start build.
2. Build Room -> join -> task doing/done -> owner testing/shipped state.
3. Setup Card -> Compare with mine -> verify no machine changes occur -> Copy recipe.
4. Test Request -> Works / Found issue using safe environment labels.
5. Help Request -> Offer help -> Friends private-chat handoff -> author Mark solved.
6. Solution -> Worked / Partly verification count.
7. Ship entry.
8. Update Pulse report -> confirm similar-environment aggregate appears when labels overlap.
9. Event -> Going/Interested RSVP.
10. Challenge -> Join -> Start a team/Build Room.
11. Save/hide local object behavior.

## 6. Two-instance relay test

With two Omarchy installations or isolated state homes:

- A creates Idea; B receives it after Sync.
- B marks interested; A count increases.
- A opens Build Room; B joins; A sees join.
- B task update appears to A.
- A Setup Card appears on B and Compare performs only local metadata comparison.
- Test result, help offer, solution verification, RSVP and challenge join all propagate.
- multi-relay duplicate copies collapse to one logical object.
- newer event for the same author/object wins.

## 7. Security regression

Confirm:

- unsigned/invalid events are rejected;
- unknown object types fail closed;
- `file://`, `javascript:` and control-character URLs do not become openable links;
- public relay objects never contain the Friends private key;
- shared setup metadata cannot execute shell/install commands;
- remote text is displayed as text, never evaluated;
- safe environment collection contains no hostname, username, IP, serial or file contents;
- `omarchy-friends://invite/<pubkey>` handler rejects every other URL shape;
- Build state remains user-only where practical;
- existing block/report/friend controls are not bypassed.

## 8. Invite desktop registration

`bin/omarchy-friends-open` implements safe URI parsing, but global desktop registration is intentionally not guessed remotely because the final installed plugin path must be known.

Determine the canonical installed path on the real machine. If Omarchy exposes a plugin lifecycle/install hook, use that supported hook to register `x-scheme-handler/omarchy-friends`. Otherwise document the smallest reliable user-local `.desktop` registration. Do not hard-code a developer checkout path.

## 9. What NOT to build in this pass

Do not spend quota inventing features. Specifically do not:

- rewrite Build Network architecture;
- auto-install setup cards;
- add remote shell execution;
- upload configs/logs/files automatically;
- replace the existing private-message crypto during this validation pass;
- rebuild V1/V2 panels (they were intentionally removed).

## 10. Final report

Return only:

- failures found;
- files changed to fix them;
- exact test results;
- screenshots of the six V3 tabs;
- two-instance relay result;
- URI registration result;
- security/privacy findings;
- whether this branch is stable enough for a second real Omarchy user.

Commit and push fixes only to `feature/build-network`. Do not merge `main`.
