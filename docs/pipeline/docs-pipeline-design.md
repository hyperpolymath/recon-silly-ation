<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
-->

# Docs-only PR pipeline: phase 1 design (draft)

> Snapshot of the docs pipeline thread, 2026-11-20. Later owner rulings (DP5 to DP12) are not folded in.
> Reconcile v0 (`src/interface/ffi/src/reconcile.zig`, #83) implements the checks against these formats.
> The schemas `docmodel.schema.json` and `findings.schema.json` beside this file are covered by the same licence (JSON has no comments).


Thread: Docs pipeline. Date: 2026-11-20. Status: read-only phase done. Blocked on owner decisions D1 to D4.

## 1. What the three tools are today

Repos were read at these heads: docudactyl `b85c9e4` (11 Nov), recon-silly-ation `09e692a` (14 Nov), plasma-parser-writer `d9998ab` (11 Nov). None ships a GitHub Action (`action.yml`).

### docudactyl (hyperpolymath/docudactyl)
- What it is: an HPC extraction engine for very large collections (PDF, OCR, audio, EPUB, geo). Chapel orchestrator over a Zig FFI layer, Idris2 ABI proofs.
- Input: a manifest of file paths. Output: per-document extraction results (Cap'n Proto, sharded), plus an offline OCaml tool `docudactyl-scm` that turns JSON or text into Scheme S-expressions.
- Invoked by: `just build-hpc`, then `bin/docudactyl-hpc --manifestPath=... --outputDir=...`, or SLURM.
- Fit for docs PRs: poor as it stands. It has no Markdown or AsciiDoc model. `text/plain` only maps to a generic "document" type. Building it in CI needs Chapel 2.8, Zig 0.15 and native libraries.

### sillybot = recon-silly-ation (hyperpolymath/recon-silly-ation), assumed
- No repo, user or code in the three orgs is named "sillybot". recon-silly-ation is the only match: a "cross-document consistency reconciler" for names, links, claims, attribution, terminology and language style. That is the job the owner described.
- State: scaffolding only. Its own README says the `reconcile` action is 0% complete and automatic edits must stay disabled until proof gates pass (issue #44). It has an Idris2/Zig ABI seam and design docs, but no checker.
- Fit: the right role, but nothing to run yet.

### plasma (hyperpolymath/plasma-parser-writer, binary `plasma`)
- What it is: a working Rust CLI. A deterministic policy engine over a "fact snapshot" of a repo.
- Commands: `check` (human, json or SARIF; exit 1 on violations), `facts` (the walk, optionally with file contents), `diff` (compare two snapshots), `fix` (dry-run plan by default, `--apply` writes with `.bak` backups), `audit` (SPDX headers), `policy validate`.
- Policies: TOML or JSON rules. Conditions can test file content by regex. Bundled policy `repo-hygiene` has 4 rules (licence file, README, SPDX present and parsing).
- Fix actions today: only `AddSpdxHeader` and `CreateFile`. The `ConsistentWith` action is reserved and rejected by the v0 loader.
- Fit: good for "walk" (facts), gate (check plus SARIF) and proof of scope (diff). Corrective work beyond headers does not exist.

Note: the README badge of plasma-parser-writer still calls it OCaml. Its own README says it is Rust. That is itself a docs inconsistency of the kind this pipeline should catch.

## 2. Proposed pipeline

One reusable workflow, `docs-pr-pipeline.yml`, called from each repo with a 5-line caller. Location is decision D3.

Stage 0. Classify. Run on `pull_request`. The PR is docs-only if every changed path matches the docs glob set (`*.adoc`, `*.md`, `docs/**`, `LICENSES/**` excluded, etc). Otherwise skip with a neutral result. Output: changed file list and base/head SHAs.

Stage 1. Ingest (docudactyl). Parse the changed docs, and the docs they link to, into one doc model: headings, anchors, links, file and command references, names, terms, spans with line and column. Output: `docmodel.json` artifact, keyed by file hash. Base and head are both ingested so later stages can compare.

Stage 2. Consistency check (recon-silly-ation). Read both doc models plus repo metadata (chora deed, README, GitHub description). Emit findings: class, severity, evidence spans, sources, and an optional proposed edit marked `unambiguous` or `ambiguous`. Output: `findings.json` and SARIF, uploaded to code scanning and summarised in one PR comment.

Stage 3. Walk and correct (plasma). `plasma facts --with-contents` before. `plasma check` with a docs policy (SPDX on prose, required files, banned patterns). For each unambiguous proposal, `plasma fix` builds a plan. Apply it in a scratch tree only. Then `plasma facts` after and `plasma diff` to prove the edit touched only the planned files and spans. Then re-run stage 2 on the result. A fix that does not clear its finding, or touches anything else, is dropped.

Stage 4. Verdict. One required check run, `docs-pipeline/verdict`:
- pass: no findings at error level and plasma check is clean.
- needs-correction: every error finding has a verified unambiguous fix. The fixes are offered for review (see below). The PR is blocked until they are taken or waived.
- fail: any ambiguous error finding, a tool disagreement, a parse failure, or stale input (base moved). A human reads the comment.

How corrective edits come back (decision D2). Recommended: the workflow never pushes. It posts the verified fixes as GitHub "suggested changes" review comments, and uploads one `plasma-fix.patch` artifact. An owning session then applies the accepted ones as one SR-011 signed commit, with the owner's go for that exact commit. This keeps every commit owner-signed and reviewable, and matches recon-silly-ation's rule that automatic mutation stays off.

Trust and safety:
- Run on `pull_request`, not `pull_request_target`. Read-only token. No secrets needed. Fork PRs work the same.
- Pin all tool versions by commit SHA in the reusable workflow.
- Tools are built once into a container image or release binaries, not compiled per run.

## 3. Gaps to build

G1. docudactyl "docs ingest" mode: a lightweight AsciiDoc and Markdown parser that emits the doc model, built without the HPC stack (OCaml side or a small standalone binary), plus a doc-model JSON schema. Largest unknown.
G2. recon-silly-ation `reconcile` v0: the first finding classes (dead links and anchors, references to missing files or commands, renames not propagated, language-policy spelling, SPDX on prose). Each with planted positive and negative fixtures, as its TEST-NEEDS requires. Output schema for findings with evidence spans.
G3. plasma: a `docs` policy file, a new fix action that applies a span-level text replacement taken from a finding (with hash check of the span), and loading of external findings. `ConsistentWith` may be the natural home.
G4. The reusable workflow, the docs-only classifier, the verdict check run, the review-comment poster and the patch artifact.
G5. Packaging: release binaries or one container image for the three tools, pinned by digest.
G6. Rollout: a caller workflow in each repo that has docs-only PRs, added through the estate's normal applier, then a first run over the 28 waiting PRs in report-only mode.

Rough order: G2 and G3 schemas first (they define the contract), then G1, G4, G5, G6. A thin v0 (D1 option 1) could cover links, missing references and SPDX in about the size of three or four PRs.

## 4. Owner decisions (sent to the hub)

D1. Interim plan for the 28 docs-only PRs. D2. How corrective edits come back. D3. Where the reusable workflow lives. D4. Confirm sillybot is recon-silly-ation.
