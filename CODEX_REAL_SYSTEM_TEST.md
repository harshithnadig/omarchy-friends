# Codex real-system validation — Omarchy Friends v4.14 RC

Branch: `feature/build-network`

This is **not** a feature-building task. Repository-side v4.14 work is complete and feature scope is frozen. Your job is to validate and fix only issues that require the actual Omarchy machine.

Do not merge into `main` unless Harshu explicitly asks.

## 1. Checkout the release candidate

```bash
git fetch origin
git switch feature/build-network
git pull --ff-only
git status --short
git rev-parse --abbrev-ref HEAD
git log -1 --oneline
```

Confirm the branch is exactly `feature/build-network` and the worktree is clean before testing.

## 2. Run the release gate first

```bash
bash scripts/release-gate.sh
```

Do not continue toward release while this prints any `FAIL`. Fix only the concrete failure, rerun the gate, and keep the change minimal.

The gate includes Python compilation, the complete unit suite, release-health validation, the remote-execution safety boundary, version alignment, and—on the real machine—Omarchy/QML validation when available.

Also run explicitly:

```bash
omarchy plugin validate .

qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml Panel.qml Service.qml \
  BuildNetworkPanelV3.qml BuildNetworkService.qml \
  GlassSurface.qml GlassPill.qml
```

## 3. Load the real plugin

Reload Omarchy shell/plugin using the normal local workflow.

Verify the normal Friends widget first:

- left-click opens Friends;
- the visible `🛠 Build` button opens Build Network;
- middle-click also opens Build Network;
- right-click cycles status;
- no QML/runtime warnings or crashes appear from either panel.

## 4. Visual V3 check

Check all six Build Network tabs: Discover, Build, Share, Help, Community and Create.

Validate:

- dark liquid-glass hierarchy renders correctly;
- no clipped text/action wrapping at normal laptop scale;
- scroll behavior is smooth;
- text inputs are readable with the active Omarchy theme;
- selected/hover states remain visible;
- Can Help / Pair controls are reachable;
- Setup Component composer is reachable from an owned Setup Card;
- GitHub pulse/publish controls are reachable from a room with a public GitHub repo;
- Help -> Solution is reachable for an owned help request;
- external Share copies text;
- Release diagnostics / Repair invites / Health controls are reachable.

Do not redesign the panel unless a real supported QML/API incompatibility forces a small fix.

## 5. Core smoke test

Use disposable titles prefixed `TEST —` because public objects are relay-readable.

Exercise:

1. Idea -> interested -> Start build.
2. Build Room -> join -> task doing/done -> owner testing/shipped state.
3. Public GitHub repo -> GitHub pulse -> explicitly publish one Project Activity card.
4. Setup Card -> Compare with mine -> verify no machine changes -> Copy recipe.
5. Owned Setup Card -> share one component -> verify metadata/link only.
6. Test Request -> Works / Found issue with safe environment labels.
7. Help Request -> Offer help -> Friends private-chat handoff -> author Mark solved.
8. Set `Can Help`, `Pair` and `Build with me` availability; confirm expiry/matching behavior.
9. Confirm a compatible Help Request shows helper matches.
10. Convert solved Help -> Solution without retyping original problem/environment.
11. Solution -> Worked / Partly verification.
12. Ship entry.
13. Update Pulse report -> confirm similar-environment aggregate when labels overlap.
14. Event -> Going/Interested RSVP.
15. Challenge -> Join -> Start a team/Build Room.
16. Save/hide local object behavior.
17. Generate external share text for public cards.
18. Use Release Health and confirm no unexpected queued-publish count/errors.

Useful probes:

```bash
python3 bin/build_network_app_v4.py status | python3 -m json.tool
python3 bin/build_network_app_v4.py health | python3 -m json.tool
python3 bin/build_network_app_v4.py inspect-environment | python3 -m json.tool
python3 bin/build_network_app_v4.py register-uri | python3 -m json.tool
```

## 6. Two-instance relay test

Use two Omarchy installations or isolated state homes.

Verify:

- A creates Idea; B receives it after Sync.
- B marks interested; A count increases.
- A opens Build Room; B joins; task/status changes propagate.
- Setup Card + Setup Component propagate.
- Can Help / Pair availability propagates and expires after its configured window.
- Project Activity cards propagate.
- Test result, help offer, solution verification, RSVP and challenge join propagate.
- multi-relay duplicate copies collapse to one logical object.
- newer event for the same author/object wins.
- force relay failure for a public post, confirm it is saved locally/queued, restore network, Sync, and confirm retry publishes it once.
- block B in Friends, then confirm B's Build Network top-level/nested activity is locally filtered on A.

## 7. Existing Friends regression

Do not approve v4.14 if Build Network breaks the existing product. Test:

- friend request/accept;
- direct messages;
- private groups;
- World presence/waves;
- Circles/community;
- Focus ritual;
- block/report behavior;
- update banner/flow;
- profile/privacy controls.

## 8. Security/privacy regression

Confirm:

- invalid signatures are rejected;
- unknown object types fail closed;
- mismatched `d`/`type` tags vs payload are rejected;
- oversized Build event content is rejected;
- unreasonable future timestamps are rejected;
- `file://`, `javascript:` and control-character URLs do not become openable shared links;
- public relay objects never contain the Friends private key;
- shared setup/component metadata cannot execute shell/install commands;
- remote text is displayed as text, never evaluated;
- safe environment collection contains no hostname, username, IP, serial or file contents;
- public GitHub snapshot accepts only HTTPS `github.com/owner/repo` URLs and uses no credentials/tokens;
- one noisy author cannot crowd the entire local Build cache;
- existing Friends blocks are not bypassed.

## 9. Invite desktop registration

Check:

```bash
xdg-mime query default x-scheme-handler/omarchy-friends
```

Then open a disposable:

```text
omarchy-friends://invite/<64-hex-pubkey>
```

Verify it reaches the installed `bin/omarchy-friends-open` handler and rejects every unsupported URL shape. Do not hard-code a developer checkout path.

## 10. What NOT to build

Do not:

- invent another social feature;
- redesign Build Network architecture;
- add remote shell execution;
- auto-install setup cards/components;
- upload configs/logs/files automatically;
- migrate private-message crypto during this RC validation;
- rebuild old V1/V2 panels.

Current private messaging ships only with accurate application-specific/not-formally-audited wording. NIP-44 migration is a separate compatibility-tested release.

## 11. Final report

Return:

- failures found;
- files changed to fix them;
- exact release-gate, unit, plugin-validation and qmllint results;
- screenshots of all six Build Network tabs;
- two-instance relay/offline-retry/helper-expiry/block result;
- existing Friends regression result;
- URI registration/open result;
- security/privacy findings;
- final answer: whether all six gates in `FINAL_RELEASE_STATUS.md` passed.

Commit/push fixes only to `feature/build-network`. Do not merge `main`.
