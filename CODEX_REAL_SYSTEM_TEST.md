# Codex real-system test checklist — Build Network v4.13 prototype

Test branch: `feature/build-network`

Do **not** merge into `main` until the checks below pass. The point of this branch is to give Codex an integrated first implementation to test and repair, not to redesign the feature set from scratch.

## 1. Checkout and protect main

```bash
git fetch origin
git switch feature/build-network
git pull --ff-only
git status --short
git rev-parse --abbrev-ref HEAD
```

Confirm the current branch is exactly `feature/build-network`. Do not commit to or merge into `main` during this test pass.

## 2. Python syntax + complete unit suite

```bash
python3 -m py_compile \
  bin/build_network.py \
  bin/build_network_social.py \
  bin/build_network_runtime.py \
  bin/build_network_app.py

python3 -m unittest discover -s tests -v
```

If anything fails, fix the branch and rerun the whole suite. Compare with `main` if an unrelated existing test fails.

## 3. Local non-network model smoke tests

These should only print bounded JSON and must not change Omarchy configuration:

```bash
python3 bin/build_network_cli.py idea "OLED system monitor" \
  --summary "A clean GPU/CPU Omarchy widget" \
  --tag QML --tag NVIDIA

python3 bin/build_network_cli.py room "OLED system monitor" \
  --goal "Ship a marketplace-ready widget" \
  --repo "https://github.com/harshithnadig/omarchy-friends" \
  --role Designer --role "AMD tester" \
  --task "Basic widget" --task "GPU support"

python3 bin/build_network_cli.py setup "Harshu setup" \
  --theme Catppuccin \
  --plugin Friends --plugin Spotify \
  --terminal Ghostty
```

## 4. Unified runtime status + safe setup inspection

```bash
python3 bin/build_network_app.py status | python3 -m json.tool
python3 bin/build_network_app.py inspect-setup | python3 -m json.tool
```

Inspect `inspect-setup` output carefully. It may include only shallow metadata such as current theme, plugin directory names, architecture/OS, shell/terminal/editor. It must **not** read or output config contents, tokens, SSH material, environment secrets, browser data or arbitrary files.

## 5. Omarchy QML validation

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml \
  Panel.qml \
  Service.qml \
  BuildNetworkPanel.qml \
  BuildNetworkService.qml
```

Fix all new branch-specific QML errors. Do not silence errors by removing functionality unless the Omarchy API truly cannot support it.

## 6. Real UI smoke test

Reload the plugin/shell using the normal Omarchy workflow. Verify:

1. **Left-click** still opens the original Friends deck.
2. **Right-click** still cycles Friends status.
3. **Middle-click** opens the new **Omarchy Build Network** deck.
4. Opening one deck closes the other.
5. Existing Chats, World, Circles, groups, DMs, focus, profile and update behavior still work.
6. Build Network tabs render: Discover, Build, Share/Test, Help, Community, Create.
7. Empty states do not crash when no Build Network object exists.
8. Closing/reopening the Build deck keeps the shell responsive.

Capture screenshots of each Build Network tab and any QML/runtime error.

## 7. Local Build Network object creation

Before testing public relay publication, create objects only if you are comfortable that they become public relay-readable cards. Use clearly disposable titles such as `TEST — Harshu Build Network`.

Exercise at least:

- Idea
- Build Room
- Join Build Room
- Setup Card using detected metadata
- Test Request + pass/issue result
- Human Help Request
- Solution Card
- Ship Post
- Update Pulse report
- Event
- Challenge

After each action, verify the UI refreshes and `python3 bin/build_network_app.py status` contains the object.

## 8. Two-instance / real relay test

This is the important integration test. Use two Omarchy Friends installations or two isolated state homes if practical.

Verify:

1. Instance A creates an Idea; B receives it after Sync.
2. B marks interested; A sees the interest count increase.
3. A promotes the Idea into a Build Room; B joins it; both see the join count.
4. A shares a Setup Card; B can **copy the recipe** but nothing auto-installs.
5. A creates a Test Request; B submits a pass/issue result; counts update.
6. A posts a Help Request; B presses chat and receives/creates the normal Friends chat invitation through the existing messaging system.
7. A posts a Solution; B can copy it.
8. A posts a Ship entry, Event, Challenge and Update Report; B sees them after Sync.
9. Duplicate copies from multiple Nostr relays collapse to one logical object.
10. A newer replaceable event for the same author/object wins over an older copy.

## 9. Security/adversarial checks

Create malformed local test payloads and/or unit tests. Confirm:

- unsigned/invalid Nostr events are rejected;
- unsupported object types are rejected;
- `file://`, `javascript:`, shell snippets and control-character URLs are stripped/rejected;
- remote cards never become process arguments except fixed safe local UI actions;
- remote text is rendered as text, not QML/HTML/code;
- Setup Cards never execute install commands;
- clicking a shared URL only sends an HTTP(S) URL to `xdg-open`;
- public cards never contain the Friends private key;
- Build state is user-only where practical;
- huge tags/text/object floods are bounded;
- hidden objects stay hidden locally;
- malformed events do not crash the persistent Friends daemon or shell.

## 10. Privacy/product checks

Confirm the UI clearly communicates:

- Build Network cards are public relay-readable metadata;
- Update Pulse is **explicit opt-in reporting**, not hidden telemetry;
- safe setup inspection does not upload dotfile contents;
- contribution reputation counts useful acts (builds/tests/solutions/ships), not followers;
- Human Help is escalation to real people, while private conversation continues through normal Friends chat.

## 11. Existing Friends regression pass

Run the existing tests again after all fixes:

```bash
python3 -m unittest discover -s tests -v
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml BuildNetworkPanel.qml BuildNetworkService.qml
```

Then test existing encrypted DM/group/community behavior manually. Build Network must not weaken or bypass existing block/report/friend-request controls.

## 12. Report back

Return:

- exact commands and results;
- every file changed while fixing;
- regressions vs `main`;
- screenshots of all Build Network tabs;
- relay interoperability findings;
- any duplicate-event or stale-cache issue;
- privacy/security findings;
- what remains prototype-quality;
- whether the Build deck is stable enough to merge visually into the main Friends panel later.

Do not merge the draft PR until Harshu explicitly decides to do so.
