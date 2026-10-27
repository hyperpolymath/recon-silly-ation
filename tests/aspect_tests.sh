#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# RSR Standard Aspect Test Template
#
# Aspect tests validate cross-cutting architectural invariants that span
# the entire codebase. These are NOT functional tests — they verify that
# coding standards, safety rules, and structural contracts hold.
#
# Usage:
#   bash tests/aspect_tests.sh
#   just aspect
#
# Standard aspects (enable what applies to your project):
#   1. SPDX compliance — all source files have license headers
#   2. Dangerous patterns — no believe_me, assert_total, sorry, unsafeCoerce, etc.
#   3. ABI/FFI contract — declarations match exports
#   4. Thread safety — mutex in FFI modules
#   5. Error handling — no panic/unreachable in production paths

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0
WARN=0

green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

pass() { green "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { red "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { yellow "  WARN: $1"; WARN=$((WARN + 1)); }

echo "═══════════════════════════════════════════════════════════════"
echo "  recon-silly-ation — Aspect Tests (Cross-Cutting Concerns)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Aspect 1: SPDX License Headers
# ═══════════════════════════════════════════════════════════════════════
bold "Aspect 1: SPDX license headers"

MISSING_SPDX=0
while IFS= read -r -d '' f; do
    if ! head -5 "$f" | grep -q "SPDX-License-Identifier"; then
        warn "Missing SPDX header: $f"
        MISSING_SPDX=$((MISSING_SPDX + 1))
    fi
done < <(find src/ -type f \( -name "*.rs" -o -name "*.zig" -o -name "*.res" -o -name "*.ex" -o -name "*.exs" -o -name "*.gleam" -o -name "*.idr" -o -name "*.sh" \) -print0 2>/dev/null)

if [ "$MISSING_SPDX" -eq 0 ]; then
    pass "All source files have SPDX headers"
else
    fail "$MISSING_SPDX files missing SPDX headers"
fi

# ═══════════════════════════════════════════════════════════════════════
# Aspect 2: Dangerous Patterns (BANNED)
# ═══════════════════════════════════════════════════════════════════════
bold "Aspect 2: Dangerous patterns"

# Idris2 dangerous patterns, in the real seam and proof tree (the template's
# src/abi/ path does not exist here, so the old grep could never fail), with
# comments and doc-comments stripped so prose naming a pattern is not a use.
# shellcheck disable=SC2016 # the single-quoted program is Perl, not shell
DANGEROUS_IDRIS=$(git ls-files -z -- 'src/*.idr' 'verification/*.idr' 2>/dev/null |
  xargs -0 -r perl -0777 -ne '
    my $f = $ARGV; my $s = $_;
    $s =~ s/\{-.*?-\}/ /gs; $s =~ s/\|\|\|[^\n]*//g; $s =~ s/--[^\n]*//g;
    print "$f: $1\n" while $s =~ /\b(really_believe_me|believe_me|assert_total)\b/g;
  ' || true)
if [ -n "$DANGEROUS_IDRIS" ]; then
    fail "Dangerous Idris2 patterns found:"
    echo "$DANGEROUS_IDRIS" | head -5
else
    pass "No dangerous Idris2 patterns (believe_me, assert_total)"
fi

# Coq/Lean/Haskell/OCaml dangerous patterns, in proof sources only and with
# comments stripped: prose that names a banned pattern ("NO Admitted allowed")
# is not a use of it. Ported from rsr-template-repo tests/aspect_tests.sh.
# shellcheck disable=SC2016 # the single-quoted program is Perl, not shell
DANGEROUS_PROOF=$(git ls-files -z -- 'src/*.v' 'verification/*.v' 'src/*.lean' 'verification/*.lean' \
    'src/*.hs' 'verification/*.hs' 'src/*.ml' 'verification/*.ml' 2>/dev/null |
  xargs -0 -r perl -0777 -ne '
    my $f = $ARGV; my $s = $_;
    if ($f =~ /\.(v|ml)$/)  { $s =~ s/\(\*.*?\*\)/ /gs }
    if ($f =~ /\.lean$/)    { $s =~ s{/-.*?-/}{ }gs; $s =~ s/--[^\n]*//g }
    if ($f =~ /\.hs$/)      { $s =~ s/\{-.*?-\}/ /gs; $s =~ s/--[^\n]*//g }
    print "$f: $1\n" while $s =~ /\b(Admitted|sorry|unsafeCoerce|Obj\.magic)\b/g;
  ' || true)
if [ -n "$DANGEROUS_PROOF" ]; then
    fail "Dangerous proof patterns found:"
    echo "$DANGEROUS_PROOF" | head -5
else
    pass "No dangerous proof patterns (Admitted, sorry, unsafeCoerce)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Aspect 3: ABI/FFI contract — the Idris2 side and the Zig side name the
# same symbols and the same library. Text-level: it checks names, not
# types (the typed cross-check is proof obligation R-9 in the ultraplan).
# ═══════════════════════════════════════════════════════════════════════
bold "Aspect 3: ABI/FFI contract"

ABI_DIR="src/interface/Abi"; FFI_SRC="src/interface/ffi/src"; FFI_BUILD="src/interface/ffi/build.zig"
if [ -d "$ABI_DIR" ] && [ -d "$FFI_SRC" ]; then
    # Every C symbol the Idris2 ABI binds: %foreign "C:<name>,<lib>"
    ABI_SYMS=$(grep -ho '%foreign "C:[A-Za-z0-9_]*,' "$ABI_DIR"/*.idr 2>/dev/null | sed -e 's/.*C://' -e 's/,$//' | sort -u)
    ABI_LIBS=$(grep -ho '%foreign "C:[A-Za-z0-9_]*,[A-Za-z0-9_]*"' "$ABI_DIR"/*.idr 2>/dev/null | sed -e 's/.*,//' -e 's/"$//' | sort -u)
    # Every symbol the Zig FFI exports, and the library name build.zig gives it.
    FFI_SYMS=$(grep -ho 'export fn [A-Za-z0-9_]*' "$FFI_SRC"/*.zig 2>/dev/null | awk '{print $3}' | sort -u)
    FFI_LIB="lib$(grep -o '\.name = "[A-Za-z0-9_]*"' "$FFI_BUILD" 2>/dev/null | head -1 | sed -e 's/.*"\(.*\)"/\1/')"

    UNBOUND=$(comm -23 <(printf '%s\n' "$ABI_SYMS") <(printf '%s\n' "$FFI_SYMS") | grep . || true)
    if [ -z "$ABI_SYMS" ]; then
        fail "ABI binds no C symbols (no %foreign declarations in $ABI_DIR)"
    elif [ -n "$UNBOUND" ]; then
        fail "ABI binds symbols the FFI does not export:"
        printf '%s\n' "$UNBOUND" | sed 's/^/    /'
    else
        pass "Every ABI-bound symbol ($(printf '%s\n' "$ABI_SYMS" | grep -c .)) is exported by the FFI"
    fi

    BAD_LIB=$(printf '%s\n' "$ABI_LIBS" | grep -v -x "$FFI_LIB" | grep . || true)
    if [ -n "$BAD_LIB" ]; then
        fail "ABI binds library '$(printf '%s' "$BAD_LIB" | tr '\n' ' ')' but build.zig builds '$FFI_LIB'"
    else
        pass "ABI library name matches build.zig ($FFI_LIB)"
    fi

    UNDECLARED=$(comm -13 <(printf '%s\n' "$ABI_SYMS") <(printf '%s\n' "$FFI_SYMS") | grep . || true)
    [ -n "$UNDECLARED" ] && warn "FFI exports not bound by the ABI (fine, but the seam is wider than the spec): $(printf '%s' "$UNDECLARED" | tr '\n' ' ')"
else
    pass "ABI/FFI not applicable (no $ABI_DIR or $FFI_SRC)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Aspect 4: Error Handling (no raw panic in production code)
# ═══════════════════════════════════════════════════════════════════════
# Uncomment for Rust projects:

# bold "Aspect 4: Error handling"
# UNWRAP_COUNT=$(grep -rn '\.unwrap()' src/ 2>/dev/null | grep -v "test" | grep -v "example" | wc -l)
# if [ "$UNWRAP_COUNT" -gt 20 ]; then
#     warn "$UNWRAP_COUNT .unwrap() calls in src/ — consider replacing with ? or expect()"
# else
#     pass "Acceptable unwrap count: $UNWRAP_COUNT"
# fi

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"
printf "  Results: "
green "PASS=$PASS" | tr -d '\n'
echo -n "  "
if [ "$FAIL" -gt 0 ]; then red "FAIL=$FAIL" | tr -d '\n'; else echo -n "FAIL=0"; fi
echo -n "  "
if [ "$WARN" -gt 0 ]; then yellow "WARN=$WARN"; else echo "WARN=0"; fi
echo ""
echo "═══════════════════════════════════════════════════════════════"

exit "$FAIL"
