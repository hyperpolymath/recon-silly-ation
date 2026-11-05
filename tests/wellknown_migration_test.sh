#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Regression tests for scripts/migrate-wellknown-to-www.sh.
#
# Shell port of the migration cases CodeRabbit added in Python on #75
# (tests/workflows/review_regressions_test.py). Python is banned in this
# estate, so the cases live here. Each case runs in a fresh temporary tree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATOR="$ROOT/scripts/migrate-wellknown-to-www.sh"
PASS=0
FAIL=0

fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }
pass() { PASS=$((PASS + 1)); }
# check MESSAGE COMMAND...: runs COMMAND as given (no eval), records the result.
check() { local msg="$1"; shift; if "$@"; then pass; else fail "$msg"; fi; }
no_match() { ! compgen -G "$1" >/dev/null; }
same() { [ "$(cat "$1")" = "$2" ]; }

# Runs the migrator in $T and records its exit status in $RC.
migrate() {
  RC=0
  (cd "$T" && bash "$MIGRATOR" "$@") >"$T/.out" 2>"$T/.err" || RC=$?
}

fresh() {
  T="$(mktemp -d)"
  mkdir -p "$T/.well-known"
}

echo "== root-only and identical tracked files migrate cleanly"
fresh
git -C "$T" init -q
mkdir -p "$T/www/.well-known"
printf 'canonical content\n' >"$T/.well-known/security.txt"
printf 'canonical content\n' >"$T/www/.well-known/security.txt"
printf 'people\n' >"$T/.well-known/humans.txt"
git -C "$T" add .
git -C "$T" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
migrate
check "exit $RC, want 0: $(cat "$T/.err")" [ "$RC" -eq 0 ]
check "legacy tree still present" [ ! -e "$T/.well-known" ]
check "canonical copy changed" [ "$(cat "$T/www/.well-known/security.txt")" = "canonical content" ]
check "root-only file not moved" [ "$(cat "$T/www/.well-known/humans.txt")" = "people" ]
rm -rf "$T"

echo "== symbolic links are explicit errors, even in --dry-run"
for target in ../target.txt ../missing.txt . ABS; do
  for mode in real dry; do
    fresh
    printf 'security contact\n' >"$T/target.txt"
    [ "$target" = ABS ] && target_path="$T/target.txt" || target_path="$target"
    ln -s "$target_path" "$T/.well-known/security.txt"
    if [ "$mode" = dry ]; then migrate --dry-run --report report.tsv; else migrate --report report.tsv; fi
    check "symlink->$target ($mode): exit $RC, want 2" [ "$RC" -eq 2 ]
    check "symlink->$target ($mode): no explicit error" grep -q "symbolic links are unsupported" "$T/.err"
    check "symlink->$target ($mode): report lacks 'left'" grep -q "^left	security.txt" "$T/report.tsv"
    check "symlink->$target ($mode): link removed" [ -L "$T/.well-known/security.txt" ]
    check "symlink->$target ($mode): target changed" [ "$(cat "$T/target.txt")" = "security contact" ]
    rm -rf "$T"
  done
done
fresh
rmdir "$T/.well-known"
ln -s missing "$T/.well-known"
migrate
check "legacy dir symlink: exit $RC, want 2" [ "$RC" -eq 2 ]
rm -rf "$T"

echo "== divergence: --dry-run touches nothing, --in-place refuses, --strict quarantines"
fresh
mkdir -p "$T/www/.well-known"
printf 'legacy\n' >"$T/.well-known/security.txt"
printf 'canonical\n' >"$T/www/.well-known/security.txt"
migrate --dry-run
check "--dry-run exit $RC, want 0" [ "$RC" -eq 0 ]
check "--dry-run changed the source" [ "$(cat "$T/.well-known/security.txt")" = "legacy" ]
check "--dry-run created a quarantine" no_match "$T/www/.legacy-*"
migrate --in-place
check "--in-place exit $RC, want 1" [ "$RC" -eq 1 ]
check "--in-place changed the source" [ "$(cat "$T/.well-known/security.txt")" = "legacy" ]
migrate --strict
check "--strict exit $RC, want 1" [ "$RC" -eq 1 ]
check "--strict overwrote the canonical copy" [ "$(cat "$T/www/.well-known/security.txt")" = "canonical" ]
q="$(compgen -G "$T/www/.legacy-*/security.txt" || true)"
check "want exactly one quarantined copy, got: $q" [ "$(printf "%s\n" "$q" | grep -c .)" -eq 1 ]
check "quarantined copy is not the legacy content" same "${q:-/nonexistent}" legacy
check "--strict left the legacy tree" [ ! -e "$T/.well-known" ]
rm -rf "$T"

echo "== a destination symlink is preserved"
fresh
mkdir -p "$T/www/.well-known"
printf 'legacy\n' >"$T/.well-known/security.txt"
ln -s missing "$T/www/.well-known/security.txt"
migrate
check "exit $RC, want 2" [ "$RC" -eq 2 ]
check "destination link replaced" [ -L "$T/www/.well-known/security.txt" ]
check "legacy file removed" [ -e "$T/.well-known/security.txt" ]
rm -rf "$T"

echo
echo "migration tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
