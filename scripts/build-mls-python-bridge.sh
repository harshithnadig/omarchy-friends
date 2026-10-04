#!/usr/bin/env bash
# Build the pinned MDK UniFFI Python bridge into an isolated output directory.
# This is packaging groundwork only; Friends does not load this bridge yet.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
experiment="$repo_root/native/mls-session-experiment"
output_dir="${1:-/tmp/omarchy-friends-mls-python-bridge}"
target_dir="${CARGO_TARGET_DIR:-$experiment/target}"
expected_mdk_revision="c977bfa844a244500590798680858b4f690d6f74"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "error: this packaging script currently supports Linux x86_64 only" >&2
    exit 1
fi
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
mdk_manifest="$(find "$cargo_home/git/checkouts" -path "*/${expected_mdk_revision:0:7}/crates/marmot-uniffi/Cargo.toml" -print -quit)"
if [[ -z "$mdk_manifest" ]]; then
    echo "error: pinned MDK checkout is missing; run cargo fetch in $experiment first" >&2
    exit 1
fi
mdk_root="$(cd "$(dirname "$mdk_manifest")/../.." && pwd)"
actual_revision="$(git -C "$mdk_root" rev-parse HEAD)"
if [[ "$actual_revision" != "$expected_mdk_revision" ]]; then
    echo "error: MDK checkout revision mismatch: $actual_revision" >&2
    exit 1
fi

mkdir -p "$target_dir"
target_dir="$(cd "$target_dir" && pwd)"
export CARGO_TARGET_DIR="$target_dir"
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_INCREMENTAL=0
# GCC 16 emits an invalid TLS relocation for SQLCipher's bundled SQLite in
# this shared-library build. Clang builds the same pinned source successfully.
if [[ "${CC:-clang}" != clang ]]; then
    echo "error: this bridge build requires clang (set CC=clang)" >&2
    exit 1
fi
export CC=clang
export CFLAGS="${CFLAGS:+$CFLAGS }-ftls-model=global-dynamic"
export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C linker=cc -C link-arg=-fuse-ld=bfd"

(
    cd "$mdk_root"
    cargo build --locked --release -p marmot-uniffi --features cli
)

library="$target_dir/release/deps/libmarmot_uniffi.so"
bindgen="$target_dir/release/uniffi-bindgen"
[[ -s "$library" && -x "$bindgen" ]] || {
    echo "error: release library or UniFFI generator was not produced" >&2
    exit 1
}

(
    cd "$mdk_root"
    "$bindgen" generate --library --language python --crate marmot_uniffi \
        --out-dir "$output_dir" "$library"
)
cp "$library" "$output_dir/libmarmot_uniffi.so"

python - "$output_dir" <<'PY'
import importlib
import pathlib
import sys

out = pathlib.Path(sys.argv[1]).resolve()
sys.path.insert(0, str(out))
module = importlib.import_module("marmot_uniffi")
if not hasattr(module, "Marmot") or not hasattr(module, "ExternalAccountSignerFfi"):
    raise SystemExit("generated binding is missing the expected MDK external-signer API")
print(f"Loaded {module.__name__} from {out}")
PY
python3 "$repo_root/scripts/smoke-mls-python-bridge.py" "$output_dir"

sha256sum "$library" > "$output_dir/libmarmot_uniffi.so.sha256"
cat > "$output_dir/build-provenance.json" <<EOF
{
  "artifact": "marmot-uniffi-python-bridge",
  "mdk_revision": "$actual_revision",
  "cargo_lock_sha256": "$(sha256sum "$mdk_root/Cargo.lock" | awk '{print $1}')",
  "rust_version": "$(cd "$mdk_root" && rustc --version)",
  "target": "$(cd "$mdk_root" && rustc -vV | sed -n 's/^host: //p')",
  "library_sha256": "$(sha256sum "$library" | awk '{print $1}')"
}
EOF
echo "Built and import-checked isolated MDK bridge at $output_dir"
