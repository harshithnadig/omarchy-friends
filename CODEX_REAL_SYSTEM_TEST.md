# Codex real-system test checklist

Test branch: `feature/build-network`

Do **not** merge into `main` until the checks below pass.

## 1. Checkout and baseline

```bash
git fetch origin
git switch feature/build-network
git pull --ff-only
python3 --version
git status --short
```

## 2. Run the complete existing test suite

```bash
python3 -m unittest discover -s tests -v
```

Do not ignore failures that existed before this branch: compare with `main` if necessary and report the difference.

## 3. Exercise the new collaboration payloads

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

python3 bin/build_network_cli.py test-request "Friends build-network beta" \
  --artifact "https://github.com/harshithnadig/omarchy-friends" \
  --want NVIDIA --want AMD --want Framework
```

Confirm each command emits valid bounded JSON and does not modify the machine.

## 4. Safety checks

Confirm the prototype:

- never executes a command from a remote payload;
- rejects unsupported payload types;
- strips non-HTTP(S) URLs;
- bounds titles, notes, tags, tasks and members;
- does not inspect or upload dotfiles, tokens, keys or private files;
- does not auto-install a shared setup;
- does not publish anything to Nostr yet.

## 5. Omarchy plugin checks

From the repository root:

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
```

The new Python files should not regress existing QML validation.

## 6. Integration reconnaissance (do not redesign blindly)

After the tests pass, inspect the current `Panel.qml`, `Service.qml`, and `bin/omarchy-friends` implementation and propose the smallest integration that:

1. exposes a `Build` surface inside the current Friends deck;
2. reuses existing identity, relay, block/report, friend/group and notification flows;
3. publishes the bounded payload formats from `bin/build_network.py` as signed Friends events;
4. never turns setup cards into arbitrary command execution;
5. keeps backward compatibility with users on older Friends versions.

Before editing QML/relay code, show the exact files and functions/components you plan to touch.

## 7. Report back

Return:

- exact test commands and results;
- any regressions vs `main`;
- screenshots of the existing Friends UI if UI integration is attempted;
- proposed relay event kind/tag strategy;
- proposed QML insertion points;
- any security or compatibility concern found.
