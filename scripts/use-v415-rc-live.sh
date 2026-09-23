#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="community.omarchy-friends"
COMMIT="${1:-}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PLUGIN_DIR="$CONFIG_HOME/omarchy/plugins/$PLUGIN_ID"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v omarchy-shell >/dev/null 2>&1 || fail "omarchy-shell is required"
[[ "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]] || fail "Pass the exact 40-character commit SHA to validate"

[[ -d "$PLUGIN_DIR/.git" ]] || fail "Installed git plugin not found at $PLUGIN_DIR"

origin="$(git -C "$PLUGIN_DIR" remote get-url origin 2>/dev/null || true)"
case "$origin" in
  *github.com/harshithnadig/omarchy-friends.git|*github.com/harshithnadig/omarchy-friends)
    ;;
  *)
    fail "Refusing to switch unexpected plugin origin: ${origin:-<none>}"
    ;;
esac

[[ -z "$(git -C "$PLUGIN_DIR" status --porcelain)" ]] \
  || fail "Installed plugin checkout has local changes. Refusing to validate it."

actual="$(git -C "$PLUGIN_DIR" rev-parse HEAD)"
[[ "${actual,,}" == "${COMMIT,,}" ]] \
  || fail "Installed commit $actual does not match requested commit $COMMIT. Install/update it explicitly first."

printf 'Validating already-installed exact commit %s at %s\n' "$COMMIT" "$PLUGIN_DIR"

printf 'Rescanning Omarchy plugins...\n'
omarchy-shell shell rescanPlugins >/dev/null
sleep 1

bash "$(dirname "$0")/verify-live-v415.sh" "$PLUGIN_DIR" "$COMMIT"

printf '\nThe exact commit was already installed; no remote source was fetched or executed.\n'
printf 'Open Friends again, then follow CODEX_REAL_SYSTEM_TEST.md for real QML, screenshots, relay and two-client validation.\n'
