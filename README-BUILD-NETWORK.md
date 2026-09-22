# Omarchy Friends Build Network — v4.14

This branch turns Omarchy Friends into an Omarchy-native social + collaboration layer while keeping the existing private messaging/World experience intact.

## Open it

- **Left-click** Friends: existing Friends deck (World, chats, Circles, groups, profile, focus).
- **Middle-click** Friends: **Build Network**.
- **Right-click** Friends: cycle status.

## Active implementation

There is one active Build UI path:

```text
BarWidget.qml
  -> BuildNetworkPanelV3.qml
  -> BuildNetworkService.qml
  -> bin/build_network_app_v2.py
  -> bin/build_network_runtime.py
```

Core public-object models live in:

```text
bin/build_network.py
bin/build_network_social.py
bin/build_network_v2.py
```

The old V1/V2 QML panels and V1 app entrypoint were removed so real-system testing does not waste time on dead prototypes.

## UI direction

V3 replaces the original dense debug-panel look with a dark **liquid-glass** design system:

- `GlassSurface.qml` — translucent layered surfaces, soft edge light and depth;
- `GlassPill.qml` — reusable capsule actions/tabs;
- larger hierarchy and whitespace;
- fewer hard borders;
- floating segmented navigation;
- clearer primary/secondary actions;
- modern glass setup comparison, help, build, pulse and create surfaces;
- responsive content width within the Omarchy popup card.

It intentionally approximates frosted glass using safe native QML layers rather than depending on an unverified blur API. A real Omarchy pass can add true compositor blur only if the shell already exposes a stable supported effect.

## Product loops implemented

### Discover

Recent useful activity only: ideas, Build Rooms, setup cards, help requests, solutions, shipped work, events and challenges. Builders get contribution-oriented reputation from useful actions rather than follower counts.

### Ideas -> Build Rooms -> Ship

Users can publish ideas, signal interest, promote an idea into a Build Room, advertise roles, join a room, link a GitHub repository, open its Issues/PRs, publish task progress, move a room through building/testing/shipped states and publish a Ship entry.

GitHub remains the code source of truth. Friends is the human discovery/coordination layer.

### Setup Cards

Setup sharing contains shallow metadata only: theme, plugin directory names, architecture/OS labels, shell, terminal, editor, optional HTTP(S) dotfiles URL and notes.

Recipients can:

- compare a shared setup against their local metadata;
- see missing/already-present plugins and differing fields;
- copy the setup recipe;
- open the author's HTTP(S) repo.

Nothing is automatically installed or executed.

### Test Network

Authors can request specific environments. Other users can report pass/issue results using safe local environment labels.

### Human escalation

A Help Request can contain the problem, a bounded description of what the user/AI already tried, and optional safe environment labels. Other users can offer help and then move to the existing Friends private chat flow. The author can mark a request solved/closed.

### Community memory

Solution Cards preserve useful fixes. Other builders can verify them as worked/partial/did-not-work, producing community evidence rather than a single unverified answer.

### Omarchy Update Pulse

Users explicitly opt in to report working/minor-issue/rolled-back for an Omarchy version. The UI shows totals plus a simple similar-environment aggregate based on safe shared labels. No background telemetry is collected.

### Events + challenges

Events support Going/Interested RSVP counts. Challenges support joining and converting the challenge into a Build Room/team.

### Save/hide

Public objects can be saved or hidden locally without changing the relay object.

## Federation

Public Build Network objects use the existing pseudonymous Friends identity when available and are published as signed Nostr parameterized-replaceable events:

- kind `30079`
- tag `t=omarchy-friends-build`
- `d=<object-id>`
- bounded normalized JSON envelope

Relay copies are de-duplicated and newer author/object versions replace older cached versions.

## Safe environment labels

The v2 runtime may locally detect only non-identifying labels such as:

- Omarchy version;
- CPU architecture;
- GPU vendor category (NVIDIA/AMD/Intel);
- kernel version label.

It does **not** collect hostname, username, IP address, serial number, tokens, config contents, SSH material or arbitrary file contents. These labels are not published unless the user explicitly performs an action that includes them.

## Invite link handler

`bin/omarchy-friends-open` safely parses only:

```text
omarchy-friends://invite/<64-hex-public-key>
```

and routes that key into the existing direct friend/chat invitation command. It never evaluates link content. Desktop URI registration still needs to be verified against the real Omarchy plugin install path before enabling it globally.

## Tests

GitHub Actions compiles all active Build Network Python modules, runs the complete repository unit suite and fails if Build Network code introduces obvious dynamic shell/eval primitives (`eval`, `exec`, `os.system`, `shell=True`).

Local validation:

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
  BarWidget.qml Panel.qml Service.qml \
  BuildNetworkPanelV3.qml BuildNetworkService.qml \
  GlassSurface.qml GlassPill.qml
```

The final two commands require a real Omarchy/Quickshell environment.

## Security boundary

Remote Build Network content is untrusted metadata. It must never become arbitrary command execution. The branch intentionally does not provide remote shell execution, automatic setup installation, arbitrary file uploads or automatic telemetry.

A future one-click setup importer must first produce an exact local review/diff plan and require explicit user confirmation for every applied change.
