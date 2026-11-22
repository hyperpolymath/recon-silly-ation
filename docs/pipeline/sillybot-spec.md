<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
-->

# sillybot adapter spec v0 (draft, per owner ruling DP5 option 1)

> Snapshot, 2026-11-20. Owner ruling DP12 since: docudactyl ingest first, then a thin adapter in bots/sillybot only; fleet wiring is a later ask.

Read from hyperpolymath/gitbot-fleet @464fa73: bots/README.adoc, docs/REPORT-BACK.adoc, shared-context/src/bot.rs, scripts/fleet-report-back.sh.

## Shape
- Location: gitbot-fleet `bots/sillybot/`. Small Rust crate: Cargo.toml, src/, tests/. Nothing else.
- No checking logic in the adapter. It runs recon-silly-ation's `reconcile` binary at a pinned commit (same pattern as panicbot with panic-attack and ponsbot with pons: `bots/sillybot/canon/pin.toml`).
- Local-directory JSON mode: `sillybot scan --path <repo> [--base <sha>]`. Prints JSON to stdout. Writes nothing into the scanned tree.

## Fleet wiring (one slot only)
1. `shared-context/src/bot.rs`: add `BotId::Sillybot`. Keep it out of `all()` at first, as ponsbot is, because it has the report-back scan mode only.
2. `scripts/fleet-report-back.sh`: one `case` arm that runs `sillybot scan` and maps findings/v0 to the envelope.
3. `scripts/fleet-report-back-build.sh`: build recon-silly-ation at the pin.
4. `tests/fleet-report-back-test.sh`: one stub with a real findings/v0 shape.

## Mapping findings/v0 to the fleet envelope
- reporter "sillybot", title "sillybot (docs consistency)".
- finding.path to file (repo-relative, no ./), span.start.line to line, class to rule_id (e.g. "SB-dead-internal-link"), severity unchanged (error, warning, info), message unchanged.
- Every finding carries a path (fleet canon rule).
- status "ran", or "error" with a reason when reconcile fails, or "not_run" when no prose changed.
- Inherited findings (introduced=false) are mapped to "info", so the grid's change-scope grading does not block on them.

## Order of work
1. recon-silly-ation: reconcile v0 that reads docmodel/v0 and emits findings/v0 (classes: dead-internal-link, dead-anchor, missing-path-reference). Fixtures per its TEST-NEEDS.
2. gitbot-fleet: the adapter and the 4 wiring steps above.

Not touched: Hypatia, the standards verdict-grid renderer, any other bot slot.
