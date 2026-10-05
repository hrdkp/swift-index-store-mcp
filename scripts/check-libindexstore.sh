#!/bin/bash
# Check the libIndexStore contract of the pinned indexstore-db revision.
#
#   Floor:   every function indexstore-db marks required must be exported by the
#            oldest supported Xcode (snapshot in ci/libindexstore-floor.symbols).
#            Fails if not: the pin needs a newer Xcode than BuildInfo.minimumXcode.
#   Ceiling: functions the selected (newest) Xcode exports that the pin never loads.
#            Warning only: upstream has moved on and the pin may be getting stale.
#
# Usage: scripts/check-libindexstore.sh [--strict] [path/to/libIndexStore.dylib]
#   --strict             treat the ceiling warning as a failure (scheduled job)
#   INDEXSTORE_DB_DIR    indexstore-db checkout to check instead of the pinned one
# Run `swift package resolve` first so the pinned indexstore-db checkout exists.
set -euo pipefail

strict=false
if [[ "${1:-}" == "--strict" ]]; then strict=true; shift; fi

root="$(cd "$(dirname "$0")/.." && pwd)"
def="${INDEXSTORE_DB_DIR:-$root/.build/checkouts/indexstore-db}/Sources/IndexStoreDB_Index/indexstore_functions.def"
floor="$root/ci/libindexstore-floor.symbols"
lib="${1:-$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib}"

fail() { echo "FAIL: $*" >&2; exit 1; }
warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::warning::$*"; else echo "WARN: $*" >&2; fi
}

[[ -f "$def" ]] || fail "missing $def (run 'swift package resolve')"
[[ -f "$floor" ]] || fail "missing $floor (run scripts/capture-libindexstore-floor.sh with the floor Xcode)"
[[ -f "$lib" ]] || fail "missing $lib"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

sed -nE 's/^INDEXSTORE_FUNCTION\(([a-z_]+), true\)/\1/p' "$def" | sort -u >"$tmp/required"
sed -nE 's/^INDEXSTORE_FUNCTION\(([a-z_]+), (true|false)\)/\1/p' "$def" | sort -u >"$tmp/loaded"
grep -v '^#' "$floor" | sort -u >"$tmp/floor"
nm -gU "$lib" | awk '$3 ~ /^_indexstore_/ { sub(/^_indexstore_/, "", $3); print $3 }' | sort -u >"$tmp/current"

[[ -s "$tmp/required" ]] || fail "parsed no required functions from $def; has its format changed?"

missing="$(comm -23 "$tmp/required" "$tmp/floor")"
if [[ -n "$missing" ]]; then
  fail "pinned indexstore-db requires functions the floor Xcode does not export:
$missing
Either keep the older pin or raise BuildInfo.minimumXcode and recapture the floor snapshot."
fi
echo "floor OK: $(wc -l <"$tmp/required" | tr -d ' ') required functions all exported by $(sed -n 's/^# xcode: //p' "$floor")"

unused="$(comm -13 "$tmp/loaded" "$tmp/current")"
if [[ -n "$unused" ]]; then
  msg="libIndexStore at $lib exports functions the pinned indexstore-db does not load; consider bumping the pin: $(echo $unused)"
  if $strict; then fail "$msg"; fi
  warn "$msg"
else
  echo "ceiling OK: pinned indexstore-db covers every function exported by $lib"
fi
