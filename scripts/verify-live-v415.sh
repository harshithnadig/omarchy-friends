#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="community.omarchy-friends"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PLUGIN_DIR="${1:-$CONFIG_HOME/omarchy/plugins/$PLUGIN_ID}"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

ok() {
  printf '[ OK ] %s\n' "$*"
}

[[ -d "$PLUGIN_DIR/.git" ]] || fail "No git-managed Friends plugin at $PLUGIN_DIR"

branch="$(git -C "$PLUGIN_DIR" branch --show-current)"
sha="$(git -C "$PLUGIN_DIR" rev-parse --short HEAD)"
printf 'Installed Friends checkout: %s\n' "$PLUGIN_DIR"
printf 'Branch: %s\n' "$branch"
printf 'Commit: %s\n' "$sha"

[[ "$branch" == "feature/build-network" ]] || fail "Live plugin is on '$branch', not feature/build-network"

grep -q '"version"[[:space:]]*:[[:space:]]*"4.15.0"' "$PLUGIN_DIR/manifest.json" \
  || fail "manifest.json is not v4.15.0"
ok "manifest v4.15.0"

grep -q 'PLUGIN_VERSION = "4.15.0"' "$PLUGIN_DIR/bin/omarchy-friends" \
  || fail "Friends engine is not v4.15.0"
ok "Friends engine v4.15.0"

grep -q 'BuildNetworkPanelV3.qml' "$PLUGIN_DIR/BarWidget.qml" \
  || fail "BarWidget is not wired to BuildNetworkPanelV3.qml"
ok "Build Network V3 loader present"

grep -q '🛠 Build' "$PLUGIN_DIR/Panel.qml" \
  || fail "Visible Build entry is missing from Panel.qml"
ok "Visible Build entry present"

grep -q 'NIP17_DM_RELAY_LIST_KIND = 10050' "$PLUGIN_DIR/bin/omarchy-friends" \
  || fail "v4.15 private inbox-relay transport is missing"
ok "NIP-17 inbox relay transport present"

printf '\nLive checkout looks like the v4.15 RC. If the rendered panel still lacks Build, the shell is serving a stale plugin instance rather than these files.\n'
