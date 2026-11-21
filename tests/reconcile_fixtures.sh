#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Planted-fixture tests for reconcile v0 (ADR 0002, report-only).
#
# Each directory under tests/fixtures/reconcile/ holds head.json, an optional
# base.json and expected.json. The runner builds the CLI, runs it on each
# case and compares the output with expected.json after jq -S. It also checks
# that bad input exits 2 and that the CLI never writes into the fixtures.
#
# Usage: tests/reconcile_fixtures.sh [path/to/zig]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFI="$ROOT/src/interface/ffi"
FIX="$ROOT/tests/fixtures/reconcile"
ZIG="${1:-zig}"

command -v jq >/dev/null || { echo "reconcile_fixtures: jq is required" >&2; exit 1; }

(cd "$FFI" && "$ZIG" build)
BIN="$FFI/zig-out/bin/reconcile"

before="$(find "$FIX" -type f -exec sha256sum {} + | sort)"
pass=0
fail=0

for dir in "$FIX"/*/; do
    name="$(basename "$dir")"
    args=(--head "$dir/head.json" --pr 1)
    [[ -f "$dir/base.json" ]] && args+=(--base "$dir/base.json")
    if diff -u <(jq -S . "$dir/expected.json") <("$BIN" "${args[@]}" | jq -S .) >/dev/null; then
        echo "PASS $name"
        pass=$((pass + 1))
    else
        echo "FAIL $name"
        diff -u <(jq -S . "$dir/expected.json") <("$BIN" "${args[@]}" | jq -S .) || true
        fail=$((fail + 1))
    fi
done

# Bad input: wrong schema, malformed JSON, missing file, no --head. Each exits 2.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo '{"schema":"other","repo":"o/r","rev":"r","files":[],"docs":[]}' > "$tmp/wrong.json"
echo '{not json' > "$tmp/broken.json"
for case in "--head $tmp/wrong.json" "--head $tmp/broken.json" "--head $tmp/absent.json" "--pr 3"; do
    set +e
    # shellcheck disable=SC2086
    "$BIN" $case >/dev/null 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 2 ]]; then
        echo "PASS exit 2: $case"
        pass=$((pass + 1))
    else
        echo "FAIL exit $rc, want 2: $case"
        fail=$((fail + 1))
    fi
done

after="$(find "$FIX" -type f -exec sha256sum {} + | sort)"
if [[ "$before" == "$after" ]]; then
    echo "PASS fixtures unchanged (report-only)"
    pass=$((pass + 1))
else
    echo "FAIL fixtures changed during the run"
    fail=$((fail + 1))
fi

echo "reconcile fixtures: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
