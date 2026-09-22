# Omarchy Friends Build Network — v4.13 prototype

This branch turns the earlier data-model experiment into an integrated Omarchy-native collaboration layer beside the existing Friends messaging deck.

## Open it

- **Left-click** the Friends bar pill: existing Friends deck.
- **Middle-click** the Friends bar pill: **Build Network** deck.
- **Right-click**: existing status-cycle behavior.

The separate deck is deliberate for this prototype: it lets the real system validate a large new surface without destabilizing the mature `Panel.qml`. Once it is reliable, the visual surfaces can be merged into the main Friends navigation.

## What is implemented

### Discover

A bounded activity surface for things people actually make or organize rather than an engagement-first infinite feed:

- shipped plugins/themes/features;
- setup cards;
- build rooms;
- ideas;
- community solutions;
- help requests;
- events;
- challenges.

It also derives contribution-oriented reputation from useful public actions (builds, setup shares, tests, solutions and ships) instead of follower counts.

### Ideas → Build Rooms

Users can:

- publish an idea;
- mark themselves interested;
- promote an idea into a Build Room;
- create Build Rooms directly;
- advertise roles needed;
- link a GitHub repository;
- join a Build Room;
- contact the owner through the existing Friends request/chat flow.

GitHub remains the code/task source of truth. Build Network is the discovery and human-coordination layer.

### Setup Cards

A Setup Card can share deliberately shallow metadata:

- theme;
- installed plugin directory names;
- architecture/OS components;
- shell;
- terminal;
- editor;
- optional dotfiles/repo URL;
- optional notes.

A recipient can **copy the recipe** or open the author's HTTP(S) URL. Nothing is auto-installed or auto-executed.

### Test Network

Plugin/theme authors can publish a test request with requested environments (for example NVIDIA, AMD, Framework). Other builders can publish signed pass/issue results from their machine.

### Human escalation

A builder can publish a bounded problem card including:

- title/problem;
- environment tags;
- a short summary of what they/their AI agent already tried.

Another builder can press Chat, which routes through the existing Friends relationship/messaging layer rather than inventing a second private-messaging system.

### Community memory

Users can publish a compact Solution Card containing the problem, solution, environment tags and optional source URL. This is an MVP for preserving useful fixes that would otherwise disappear in chat history.

### Ship Log

Builders can publish a shipped plugin/theme/feature card with summary, tags and artifact URL. Discover surfaces these alongside active work.

### Omarchy Update Pulse

Users may **explicitly** publish an update report for an Omarchy version:

- working;
- minor issue;
- rolled back.

Build Network aggregates these public voluntary reports. There is no hidden telemetry or automatic machine reporting.

### Events and challenges

Users can publish lightweight meetup/online-event cards and community build challenges. Challenges can be turned into Build Rooms.

## Federation

The prototype reuses the Friends pseudonymous secp256k1 identity when available and publishes signed Nostr events using:

- kind: `30079` (parameterized replaceable);
- tag: `t=omarchy-friends-build`;
- `d=<object-id>`;
- a bounded JSON envelope containing one normalized public object.

Multiple relay copies are de-duplicated. The newest event for the same author/object replaces an older cached version.

The default relay list follows the existing Friends relay configuration and honors `OMARCHY_FRIENDS_RELAYS`.

## Local state

Build Network keeps a separate cache at:

```text
$XDG_STATE_HOME/omarchy-friends/build_network_state.json
```

or the corresponding `~/.local/state` path.

The existing Friends private key is not copied into public objects or output. A fallback local identity exists only for testing before the main Friends identity has been initialized.

## Main files

```text
BuildNetworkPanel.qml        Build Network UI
BuildNetworkService.qml      QML ↔ Python bridge
bin/build_network.py         core collaboration models
bin/build_network_social.py  help/solutions/ship/update/event/challenge models
bin/build_network_runtime.py relay/cache/runtime implementation
bin/build_network_app.py     unified CLI/runtime exposed to QML
```

## Validation

Run:

```bash
python3 -m py_compile \
  bin/build_network.py \
  bin/build_network_social.py \
  bin/build_network_runtime.py \
  bin/build_network_app.py

python3 -m unittest discover -s tests -v

omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml Panel.qml Service.qml \
  BuildNetworkPanel.qml BuildNetworkService.qml
```

For the full real-system workflow, follow `CODEX_REAL_SYSTEM_TEST.md`.

## Security boundary

Public Build Network data must be treated as untrusted text/metadata. The prototype intentionally does **not** provide remote command execution, config installation, remote file upload, shell snippets, package installation or automatic telemetry.

Shared URLs are limited to HTTP(S). Setup recipes are copied for review rather than applied. Any future one-click setup import must first produce a local diff/review plan and must never execute arbitrary text received from a relay.
