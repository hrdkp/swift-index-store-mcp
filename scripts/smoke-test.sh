#!/bin/bash
# Smoke-test a built index-store-mcp binary without needing an Xcode index.
# Usage: scripts/smoke-test.sh /path/to/index-store-mcp
set -euo pipefail

bin="${1:?usage: smoke-test.sh /path/to/index-store-mcp}"
fail() { echo "FAIL: $*" >&2; exit 1; }

# The binary's deployment target must match the floor declared in Package.swift.
# A dependency or manifest change that raises it would silently drop users.
root="$(cd "$(dirname "$0")/.." && pwd)"
expected_minos="$(sed -nE 's/.*\.macOS\(\.v([0-9]+)\).*/\1.0/p' "$root/Package.swift")"
[[ -n "$expected_minos" ]] || fail "could not read the macOS platform from Package.swift"
minos="$(vtool -show-build "$bin" | awk '$1 == "minos" { print $2 }' | sort -u)"
[[ "$minos" == "$expected_minos" ]] || fail "minos is '$minos', expected $expected_minos"
echo "minos: $minos"

# Flag checks read stdin from /dev/null so a binary that ignores the flag and
# starts the stdio server sees EOF and exits, instead of hanging CI.
# --version prints a semantic version and exits 0.
version="$("$bin" --version </dev/null)" || fail "--version exited non-zero"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+].*)?$ ]] || fail "--version output is not a version: '$version'"
echo "version: $version"

# --help exits 0 and mentions the prerequisites a confused user needs.
help="$("$bin" --help </dev/null)" || fail "--help exited non-zero"
grep -q "DerivedData" <<<"$help" || fail "--help does not mention DerivedData"

# --print-agent-instructions prints a snippet and exits 0.
"$bin" --print-agent-instructions </dev/null | grep -q "index-store-mcp" || fail "--print-agent-instructions output missing"

# Server mode: stdout must carry only JSON-RPC. Run a handshake and check
# every stdout line is a JSON object, the server identifies itself, and all
# tools are listed.
out="$(
  { printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}' \
      '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
      '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    sleep 2
  } | "$bin" 2>/dev/null
)"

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \{*\} ]] || fail "non-JSON line on stdout: '$line'"
done <<<"$out"

grep -q '"name":"index-store-mcp"' <<<"$out" || fail "server did not identify as index-store-mcp"
for tool in loadIndex searchSymbol searchSymbolPattern symbolAtPosition \
            getOccurrences relatedOccurrences symbolsInFile refreshIndex; do
  grep -q "\"name\":\"$tool\"" <<<"$out" || fail "tool missing from tools/list: $tool"
done
echo "OK: $bin"
