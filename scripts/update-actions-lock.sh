#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Regenerate action pins, then restore license headers displaced by the banner.
# Usage: bash scripts/update-actions-lock.sh [--relock]
set -euo pipefail

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --relock ]; }; then
    echo 'Usage: bash scripts/update-actions-lock.sh [--relock]' >&2
    exit 2
fi
cd "$(dirname "${BASH_SOURCE[0]}")/.."
gh actions-lock "$@"

python3 - <<'PY'
from pathlib import Path

banner = '# This workflow is managed by gh actions-lock.'
for path in sorted(Path('.github/workflows').glob('*')):
    if path.suffix not in {'.yml', '.yaml'}:
        continue
    lines = path.read_text().splitlines(keepends=True)
    header_end = 0
    while header_end < len(lines) and (lines[header_end].startswith('#') or not lines[header_end].strip()):
        header_end += 1
    header = lines[:header_end]
    licenses = [line for line in header if line.startswith('# SPDX-License-Identifier:')]
    if len(licenses) == 1 and any(line.rstrip() == banner for line in header):
        rest = [line for line in header if line not in licenses and line.rstrip() != banner]
        path.write_text(licenses[0] + banner + '\n' + ''.join(rest + lines[header_end:]))
PY
