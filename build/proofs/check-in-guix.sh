#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# check-in-guix.sh PROVER...   run scripts/check-proofs.sh inside the Guix shell
#
# Run under `guix shell -m build/proofs/manifest.scm` (see channels.scm). It
# prints each tool's version, then makes the Guix standard library Agda's
# default library (Guix's Agda finds libraries through AGDA_LIBDIRS but
# enables none by default), then runs the gate for each prover named. The
# exit status is the number of provers that failed; nothing is skipped.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

[ "$#" -gt 0 ] || { echo "usage: $0 PROVER..." >&2; exit 2; }

agda_setup() {
  local lib
  lib=$(find "${GUIX_ENVIRONMENT:?run inside guix shell}/lib/agda" -name '*.agda-lib' -path '*stdlib*' | head -1)
  [ -n "$lib" ] || { echo "FAIL: no standard library .agda-lib under $GUIX_ENVIRONMENT/lib/agda" >&2; return 1; }
  AGDA_DIR=$(mktemp -d)
  export AGDA_DIR
  printf '%s\n' "$lib" > "$AGDA_DIR/libraries"
  sed -n 's/^name:[[:space:]]*//p' "$lib" > "$AGDA_DIR/defaults"
  echo "agda: standard library $(cat "$AGDA_DIR/defaults") from $lib"
}

failed=0
for p in "$@"; do
  case "$p" in
    idris2) idris2 --version ;;
    agda)   agda --version; agda_setup ;;
    coq)    coqc --version ;;
    lean4)  lean --version ;;
    *) echo "unknown prover: $p" >&2; exit 2 ;;
  esac
  bash scripts/check-proofs.sh "$p" || failed=$((failed + 1))
done
exit "$failed"
