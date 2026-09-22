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

[[ -f "$PLUGIN_DIR/FriendsPanelV3.qml" ]] || fail "FriendsPanelV3.qml is missing from the installed plugin"
grep -q 'FriendsPanelV3.qml' "$PLUGIN_DIR/BarWidget.qml" \
  || fail "BarWidget is not wired to FriendsPanelV3.qml"
grep -q 'FriendsPanelV2.qml' "$PLUGIN_DIR/BarWidget.qml" \
  || fail "Friends V2 compatibility fallback is missing"
grep -q 'compatibilityPanelLoader.status === Loader.Error' "$PLUGIN_DIR/BarWidget.qml" \
  || fail "legacy fallback is not gated behind the V2 fallback"
ok "Friends V3 -> V2 -> legacy fallback chain present"

grep -q 'text: "Requests"' "$PLUGIN_DIR/FriendsPanelV3.qml" \
  || fail "Friends V3 dedicated Requests surface is missing"
grep -q 'function conversationFriends()' "$PLUGIN_DIR/FriendsPanelV3.qml" \
  || fail "Friends V3 conversation-only Chats filtering is missing"
grep -q 'text: "Omarchy Circle"' "$PLUGIN_DIR/FriendsPanelV3.qml" \
  || fail "Friends V3 Circle room UI is missing"
grep -q 'text: "Privacy"' "$PLUGIN_DIR/FriendsPanelV3.qml" \
  || fail "Friends V3 privacy UI is missing"
ok "Friends V3 Chats / Requests / World / Circles / Me contract present"

grep -q 'BuildNetworkPanelV3.qml' "$PLUGIN_DIR/BarWidget.qml" \
  || fail "BarWidget is not wired to BuildNetworkPanelV3.qml"
grep -q 'text: "Build"' "$PLUGIN_DIR/FriendsPanelV3.qml" \
  || fail "Visible Build entry is missing from FriendsPanelV3.qml"
ok "Build Network V3 loader and visible Build entry present"

grep -q 'NIP17_DM_RELAY_LIST_KIND = 10050' "$PLUGIN_DIR/bin/omarchy-friends" \
  || fail "v4.15 private inbox-relay transport is missing"
ok "NIP-17 inbox relay transport present"

[[ ! -e "$PLUGIN_DIR/bin/omarchy-friends-auto-update" ]] \
  || fail "silent auto-update helper should not exist in v4.15"
! grep -q 'autoUpdate' "$PLUGIN_DIR/ServiceModern.qml" \
  || fail "ServiceModern.qml still contains background update behavior"
ok "updates remain explicit/user-triggered"

printf '\nLive checkout contains the v4.15 Friends V3 RC. Next run the release gate, plugin validation, qmllint and screenshot/interaction checklist from CODEX_REAL_SYSTEM_TEST.md.\n'
