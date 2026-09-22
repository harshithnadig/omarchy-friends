#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="community.omarchy-friends"
BRANCH="${1:-feature/build-network}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PLUGIN_DIR="$CONFIG_HOME/omarchy/plugins/$PLUGIN_ID"
EXPECTED_REPO="harshithnadig/omarchy-friends"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v omarchy-shell >/dev/null 2>&1 || fail "omarchy-shell is required"

[[ -d "$PLUGIN_DIR/.git" ]] || fail "Installed git plugin not found at $PLUGIN_DIR"

origin="$(git -C "$PLUGIN_DIR" remote get-url origin 2>/dev/null || true)"
case "$origin" in
  *github.com/harshithnadig/omarchy-friends.git|*github.com/harshithnadig/omarchy-friends)
    ;;
  *)
    fail "Refusing to switch unexpected plugin origin: ${origin:-<none>}"
    ;;
esac

if [[ -n "$(git -C "$PLUGIN_DIR" status --porcelain)" ]]; then
  fail "Installed plugin checkout has local changes. Refusing to overwrite them."
fi

printf 'Live plugin directory: %s\n' "$PLUGIN_DIR"
printf 'Fetching %s from %s...\n' "$BRANCH" "$EXPECTED_REPO"
git -C "$PLUGIN_DIR" fetch origin "$BRANCH"

if git -C "$PLUGIN_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git -C "$PLUGIN_DIR" switch "$BRANCH"
else
  git -C "$PLUGIN_DIR" switch --track -c "$BRANCH" "origin/$BRANCH"
fi

git -C "$PLUGIN_DIR" pull --ff-only origin "$BRANCH"

printf 'Rescanning Omarchy plugins...\n'
omarchy-shell shell rescanPlugins >/dev/null
sleep 1

"$(dirname "$0")/verify-live-v415.sh" "$PLUGIN_DIR"

printf '\nRC is now the live installed checkout.\n'
printf 'Open Friends again. You should see a visible Build entry, and middle-clicking the bar widget should open Build Network V3.\n'
