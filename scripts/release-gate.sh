#!/usr/bin/env bash
# Omarchy Friends v4.15 release-candidate verification
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CI_MODE=0
if [[ "${1:-}" == "--ci" ]]; then
  CI_MODE=1
fi

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }

required=(
  manifest.json
  BarWidget.qml
  FriendsPanelV3.qml
  FriendsPanelV2.qml
  Panel.qml
  Service.qml
  ServiceModern.qml
  BuildNetworkPanelV3.qml
  BuildNetworkService.qml
  GlassSurface.qml
  GlassPill.qml
  GlassButton.qml
  GlassField.qml
  GlassNavItem.qml
  GlassAvatar.qml
  bin/build_network_app_v4.py
  bin/omarchy-friends
  bin/omarchy-friends-open
  PROMISE_LEDGER.md
  CODEX_REAL_SYSTEM_TEST.md
)
for file in "${required[@]}"; do
  [[ -f "$file" ]] || fail "missing $file"
done
pass "required release files exist"

[[ ! -f BuildNetworkPanel.qml ]] || fail "obsolete BuildNetworkPanel.qml still exists"
[[ ! -f BuildNetworkPanelV2.qml ]] || fail "obsolete BuildNetworkPanelV2.qml still exists"
[[ ! -f bin/omarchy-friends-auto-update ]] || fail "silent auto-update helper still exists"
[[ ! -f .github/workflows/request-management-patcher.yml ]] || fail "one-shot write-capable request migration workflow still exists"
[[ ! -f scripts/_request_patch.py ]] || fail "one-shot request migration script still exists"
[[ ! -f .github/workflows/v3-safety-patcher.yml ]] || fail "one-shot write-capable V3 safety workflow still exists"
[[ ! -f scripts/_v3_safety_patch.py ]] || fail "one-shot V3 safety migration script still exists"
pass "obsolete panels, silent updater, and one-shot migration helpers are absent"

grep -q 'FriendsPanelV3.qml' BarWidget.qml || fail "bar widget is not loading Friends V3"
grep -q 'FriendsPanelV2.qml' BarWidget.qml || fail "Friends V2 compatibility fallback is missing"
grep -q 'Panel.qml' BarWidget.qml || fail "legacy Friends fallback is missing"
grep -q 'BuildNetworkPanelV3.qml' BarWidget.qml || fail "bar widget is not loading Build Network V3"
grep -q 'build_network_app_v4.py' BuildNetworkService.qml || fail "Build Network service is not using v4 hardening runtime"
grep -q 'function openBuildTab' BarWidget.qml || fail "first-class Build navigation hook is missing"

grep -q 'text: "Requests"' FriendsPanelV3.qml || fail "Friends V3 is missing the dedicated Requests view"
grep -q 'function conversationFriends()' FriendsPanelV3.qml || fail "Friends V3 is missing conversation-only chat filtering"
grep -q 'text: "Decline"' FriendsPanelV3.qml || fail "received requests cannot be declined"
grep -q 'text: "Cancel"' FriendsPanelV3.qml || fail "sent requests cannot be cancelled"
grep -q 'function declineFriendRequest' Service.qml || fail "Service is missing the decline request wrapper"
grep -q 'function cancelFriendRequest' Service.qml || fail "Service is missing the cancel request wrapper"
grep -q 'def decline_friend_request' bin/omarchy-friends || fail "Friends engine is missing decline request support"
grep -q 'def cancel_friend_request' bin/omarchy-friends || fail "Friends engine is missing cancel request support"
grep -q '"friend_decline"' bin/omarchy-friends || fail "Friends engine is missing decline synchronization"
grep -q '"friend_cancel"' bin/omarchy-friends || fail "Friends engine is missing cancel synchronization"

grep -q 'function hidePeer' FriendsPanelV3.qml || fail "Friends V3 is missing Hide safety handling"
grep -q 'function reportPeer' FriendsPanelV3.qml || fail "Friends V3 is missing Report safety handling"
grep -q 'text: "Hide builder"' FriendsPanelV3.qml || fail "World is missing on-demand Hide action"
grep -q 'text: "Report"' FriendsPanelV3.qml || fail "Friends V3 is missing Report action"
grep -q 'function blockGlobal' Service.qml || fail "Service is missing the block/hide action"

! grep -q 'autoUpdate' ServiceModern.qml || fail "manifest service entry point still contains background update behavior"
pass "active Friends V3 paths, request lifecycle, people safety, and explicit updates are wired"

python3 -m py_compile \
  bin/build_network.py \
  bin/build_network_social.py \
  bin/build_network_v2.py \
  bin/build_network_v3.py \
  bin/build_network_runtime.py \
  bin/build_network_app_v2.py \
  bin/build_network_app_v3.py \
  bin/build_network_app_v4.py \
  bin/omarchy_friends_global.py \
  bin/omarchy_friends_private.py \
  bin/omarchy-friends \
  bin/omarchy-friends-open
pass "Python modules compile"

python3 -m unittest discover -s tests -v
pass "unit suite passes"

if grep -R -nE 'eval\(|exec\(|os\.system\(|shell=True' \
  bin/build_network*.py bin/omarchy_friends_*.py bin/omarchy-friends bin/omarchy-friends-open; then
  fail "remote-execution safety boundary violated"
fi
pass "no forbidden remote-exec primitives in active Friends/Build Python"

manifest_version="$(python3 - <<'PY'
import json
print(json.load(open('manifest.json', encoding='utf-8'))['version'])
PY
)"
engine_version="$(python3 - <<'PY'
import re
text = open('bin/omarchy-friends', encoding='utf-8').read()
m = re.search(r'^PLUGIN_VERSION\s*=\s*"([^"]+)"', text, re.M)
print(m.group(1) if m else '')
PY
)"

[[ -n "$manifest_version" ]] || fail "manifest version is empty"
[[ -n "$engine_version" ]] || fail "Friends engine version is missing"
[[ "$manifest_version" == "$engine_version" ]] || fail "version mismatch: manifest=$manifest_version engine=$engine_version"
pass "manifest and live Friends engine advertise $manifest_version"

TMP_STATE="$(mktemp -d)"
trap 'rm -rf "$TMP_STATE"' EXIT
XDG_STATE_HOME="$TMP_STATE" python3 bin/build_network_app_v4.py health >/tmp/omarchy-friends-release-health.json
python3 - <<'PY'
import json
p = json.load(open('/tmp/omarchy-friends-release-health.json', encoding='utf-8'))
assert p['ok'] is True
assert int(p['state_schema']) >= 2
print('PASS  release health command works')
PY

if [[ "$CI_MODE" -eq 0 ]] && command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate .
  pass "omarchy plugin validate"
else
  warn "omarchy plugin validation skipped outside a real Omarchy environment"
fi

if [[ "$CI_MODE" -eq 0 ]] && command -v qmllint >/dev/null 2>&1 && [[ -n "${OMARCHY_PATH:-}" ]]; then
  qmllint -I "$OMARCHY_PATH/shell" \
    BarWidget.qml FriendsPanelV3.qml FriendsPanelV2.qml Panel.qml \
    ServiceModern.qml Service.qml \
    BuildNetworkPanelV3.qml BuildNetworkService.qml \
    GlassSurface.qml GlassPill.qml GlassButton.qml GlassField.qml \
    GlassNavItem.qml GlassAvatar.qml
  pass "QML lint against installed Omarchy imports"
else
  warn "QML/Omarchy runtime lint requires the real machine"
fi

printf '\nRelease gate complete.\n'
