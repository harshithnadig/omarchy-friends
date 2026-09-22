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
  FriendsPanelV2.qml
  Panel.qml
  Service.qml
  BuildNetworkPanelV3.qml
  BuildNetworkService.qml
  GlassSurface.qml
  GlassPill.qml
  GlassButton.qml
  GlassField.qml
  GlassNavItem.qml
  GlassAvatar.qml
  bin/build_network_app_v4.py
  PROMISE_LEDGER.md
  CODEX_REAL_SYSTEM_TEST.md
)
for file in "${required[@]}"; do
  [[ -f "$file" ]] || fail "missing $file"
done
pass "required release files exist"

[[ ! -f BuildNetworkPanel.qml ]] || fail "obsolete BuildNetworkPanel.qml still exists"
[[ ! -f BuildNetworkPanelV2.qml ]] || fail "obsolete BuildNetworkPanelV2.qml still exists"
pass "only the V3 Build Network panel remains"

grep -q 'FriendsPanelV2.qml' BarWidget.qml || fail "bar widget is not loading the modern Friends shell"
grep -q 'Panel.qml' BarWidget.qml || fail "legacy Friends fallback is missing"
grep -q 'BuildNetworkPanelV3.qml' BarWidget.qml || fail "bar widget is not loading Build Network V3"
grep -q 'build_network_app_v4.py' BuildNetworkService.qml || fail "Build Network service is not using v4 hardening runtime"
grep -q 'function openBuildTab' BarWidget.qml || fail "first-class Build navigation hook is missing"
pass "active UI/runtime paths are final"

python3 -m py_compile \
  bin/build_network.py \
  bin/build_network_social.py \
  bin/build_network_v2.py \
  bin/build_network_v3.py \
  bin/build_network_runtime.py \
  bin/build_network_app_v2.py \
  bin/build_network_app_v3.py \
  bin/build_network_app_v4.py \
  bin/omarchy_friends_private.py \
  bin/omarchy-friends-open
pass "Python modules compile"

python3 -m unittest discover -s tests -v
pass "unit suite passes"

if grep -R -nE 'eval\(|exec\(|os\.system\(|shell=True' bin/build_network*.py bin/omarchy-friends-open; then
  fail "remote-execution safety boundary violated"
fi
pass "no forbidden remote-exec primitives in Build Network"

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

if [[ "$manifest_version" != "$engine_version" ]]; then
  if [[ "$CI_MODE" -eq 1 ]]; then
    warn "manifest is $manifest_version but main Friends engine advertises $engine_version; final local release gate must fix this"
  else
    fail "version mismatch: manifest=$manifest_version engine=$engine_version"
  fi
else
  pass "manifest and live Friends engine advertise $manifest_version"
fi

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
    BarWidget.qml FriendsPanelV2.qml Panel.qml Service.qml \
    BuildNetworkPanelV3.qml BuildNetworkService.qml \
    GlassSurface.qml GlassPill.qml GlassButton.qml GlassField.qml \
    GlassNavItem.qml GlassAvatar.qml
  pass "QML lint against installed Omarchy imports"
else
  warn "QML/Omarchy runtime lint requires the real machine"
fi

printf '\nRelease gate complete.\n'
