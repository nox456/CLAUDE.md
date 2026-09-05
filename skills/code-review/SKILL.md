---
name: code-review
description: Review code for functional defects — bugs, broken edge cases, unmet requirements — against the PRD or implementation plan it was built from, reporting each finding as severity (BLOCKING/HIGH/MEDIUM/LOW) + location + cause + a concrete fix, and closing with a merge-readiness score. Requires a PRD or implementation plan file and refuses to run without one. Report-only: applies no fixes, runs no tests, posts nothing. Use when asked to "review this code", "review my changes", "review this PR", "find bugs in what I just wrote", "is this ready to merge", "check the implementation against the plan", or when invoked as /code-review — including when the user asks for a review without naming a document. Does not cover refactor findings (duplication, naming, dead code, repo conventions) — that is the `refactor-review` skill's ground, and it runs after this one. Findings stay in the conversation: publishing them as inline comments on a GitHub PR is `pr-review`'s ground, and it calls this skill for the analysis.
---

# Review Code Against Its Spec

Produces a severity-ranked list of **functional** defects — bugs, broken edge cases, unmet
requirements — judged against the PRD or implementation plan the code was written from, and
closes with a merge-readiness score. The document is the standard: without it a review can
only say "this code is self-consistent", which is the failure mode this skill exists to
prevent — code that works perfectly and does the wrong thing.

## Ground rules

- **No document, no review.** A PRD or implementation plan file is a hard precondition
  (step 1). If there is none, stop and ask for one. Do not review "just the diff".
- **Functionality only.** A finding qualifies only if applying its fix **changes observable
  behavior**. Duplication, naming, dead code, file layout, missing abstractions, repo
  conventions — all out of scope, all owned by the `refactor-review` skill. If you catch yourself
  writing one, delete it rather than downgrading it to LOW.
- **Report only.** Edit nothing, write no files, run no formatters, post nothing to GitHub.
  Findings live in the conversation. Do not run the test suite either — this is a reading
  pass; if a test would settle a suspicion, say so in the finding.
- **Confirm before reporting.** Every finding names code you have actually read at the
  reviewed ref. A suspicion you could not confirm is either dropped or stated as uncertain
  in its Description — never dressed up as fact.
- **Every code finding carries a fix.** A location without a suggestion is half a review.
- **The exact output format is non-negotiable** (step 4). Same five lines, same order, every
  finding, no extra prose between them.

## Workflow

- [ ] Step 1 — Load the spec document (hard gate)
- [ ] Step 2 — Resolve the review scope and read the code
- [ ] Step 3 — Run the four analysis passes
- [ ] Step 4 — Write the findings in the required format
- [ ] Step 5 — Self-review, score, hand off

---

### Step 1 — Load the spec document (hard gate)

Find and **read into context** the PRD or implementation plan behind this code, in this order:

1. A path the user named.
2. A plan or PRD file in the repo. Search by content, not by filename convention:
   ```bash
   rg -l --iglob '*.md' -e '^# PRD' -e 'Implementation Plan' -e 'Acceptance criteria'
   ```
   then check `docs/plans/`, `docs/`, and the repo root for anything the search missed.
3. A plan linked from the branch's issue or PR body.

Read the whole document, not its headings. What you extract from it is the review's yardstick:

- the numbered requirements (FR-n / TR-n) and acceptance criteria
- the **Contracts** section — types, schemas, endpoint and payload shapes, DDL
- **Design decisions** — what was deliberately chosen *and* rejected
- **Out of scope** and open questions — these bound what may be reported as missing
- the build sequence, migration/rollout, and rollback path

**If no such document exists, stop.** Say plainly that the review cannot start without one,
name where you looked, and offer `/write-implementation-plan` or `/write-prd` first. An issue
title, a PR description, a Slack paste, or the diff itself is **not** a substitute — do not
proceed on one, even if the user pushes. A stale document is fine: review against it and
report the drift as a finding.

### Step 2 — Resolve the review scope and read the code

Pick the scope once and reuse it for every pass:

| The user gave | Scope |
| --- | --- |
| A PR number or URL | `gh pr diff <n>` for the patch, `gh pr view <n>` for metadata |
| Nothing, on a feature branch | `git diff main...HEAD`, plus `git diff HEAD` if the tree is dirty |
| A path or directory | Everything under it that the document covers |

Never `gh pr checkout` — it moves the user's branch. To read PR files whole, fetch the ref
instead: `git fetch origin pull/<n>/head:pr-<n>`, then `git show pr-<n>:<path>`.

**The diff is the entry point, not the reading material.** For every changed function, read
the whole function, its callers (`rg` the symbol), and the types it consumes. Bugs live at
the seam between a changed hunk and the unchanged code around it — a diff-only pass cannot
see them. In an unfamiliar repo, dispatch `Explore` agents per surface rather than reading
broadly yourself.

### Step 3 — Run the four analysis passes

Read `references/analysis-passes.md` now, before writing any finding — it holds the probes
for each pass and the rules for confirming a suspicion.

1. **Requirement traceability** — every numbered requirement and acceptance criterion in the
   document → the code that satisfies it → implemented / partial / missing / contradicted.
2. **Contract conformance** — the document's declared shapes vs. what the code exposes, and
   every caller vs. every callee.
3. **Behavior under stress** — the functional bug classes: order of operations, async and
   concurrency, error paths, boundaries, empty and null, idempotency, transactions and
   partial writes, permissions, timezones, cache and flag states.
4. **Blast radius** — what the change breaks in code it did not touch: existing callers,
   deployed clients in the compatibility window, in-flight jobs, stored rows written by the
   old code, the rollback path.

Passes 1 and 2 are the ones a document-less review cannot do. Do them first, and do not skip
them because pass 3 is already producing findings.

### Step 4 — Write the findings in the required format

Sort by severity descending, then number from 1. Same five lines each, nothing between them:

```
1. Retry loop re-charges the card on a timeout
Severity: BLOCKING
Location: packages/api/src/payments/charge.ts:88-112
Description: The retry wraps the whole `chargeCard` call instead of the response read, so a
gateway timeout after a successful authorization charges the customer twice.
Suggestion: Pass the idempotency key the plan's Contracts section defines:
`await gateway.charge({ ...payload, idempotencyKey: intent.id })`

2. Missing requirement: FR-4 (export excludes voided invoices)
Severity: HIGH
Location: Multiple locations: exportInvoices.ts, invoiceFilters.ts
Description: FR-4 requires voided invoices to be omitted from the CSV export; no filter on
`status` exists on either path, so voided rows are exported.
Suggestion: Filter at the query, not in the formatter — add `.where(eq(invoice.status, 'issued'))`
```

Rules for the fields:

- **Location** — `path:line` or `path:start-end`, taken from the **file at the reviewed ref**,
  never from diff hunk offsets. When one defect spans files, write
  `Multiple locations: <file1>, <file2>` with no line numbers. For a finding with no code site
  (a requirement nothing implements), name the artifact that should have contained it.
- **Description** — 1–2 sentences on the *cause and the consequence*. Not a restatement of
  the title, not a lecture on the pattern.
- **Suggestion** — a snippet in the repo's language using the real identifiers, or one short
  sentence when the fix is an action ("add an integration test covering the flag-off path").
  Short: the shape of the fix, not the patch.

Severity anchors — apply these, not intuition:

| Label | Merging it means |
| --- | --- |
| **BLOCKING** | Data loss or corruption, money moved wrongly, an auth or permission hole, a production path that breaks, or a stated requirement of the document that is simply not implemented. No workaround. |
| **HIGH** | A real bug on a path users will hit — wrong result, unhandled error, race — but recoverable or bounded in blast radius. |
| **MEDIUM** | Fails on a plausible but uncommon input or state; a requirement implemented only partially; a failure that degrades behavior instead of breaking it. |
| **LOW** | Narrow or unlikely case, missing defensive guard, drift from the document with no behavioral consequence today. |

If a finding cannot be placed by that table, it is probably a refactor finding — drop it.

### Step 5 — Self-review, score, hand off

Check the draft against `references/review-checklist.md` and fix what fails before showing
anything. Then compute the verdict from the final counts — show the arithmetic:

```
Score = 100 − (40 × BLOCKING) − (15 × HIGH) − (5 × MEDIUM) − (1 × LOW)
Any BLOCKING caps the score at 35. Floor at 0.
```

| Score | Verdict |
| --- | --- |
| 90–100 | **Merge** — nothing outstanding, or LOWs the author can take or leave |
| 70–89 | **Merge after fixes** — address the HIGHs, MEDIUMs are the author's call |
| 40–69 | **Changes required** — re-review after the fixes land |
| 0–39 | **Do not merge** — the implementation does not yet do what the document specifies |

Close with, in this order: the counts per severity, the arithmetic line, the score and its
band, and the shortlist of findings that must be fixed before merge. Then stop — offer to
re-review after fixes, run `refactor-review` for the refactor pass, or hand these findings to
`pr-review` to publish them on the PR as inline comments; do none of them unasked.

## Gotchas

- **This skill installs as `/code-review` and shadows Claude Code's built-in `/code-review`.**
  Never invoke `/code-review` from inside a run — it resolves back here. The built-in's
  reuse/simplification half is not lost: it lives in the `refactor-review` skill, which is the
  right referral for anything this skill rules out of scope.
- Diff hunk headers (`@@ -12,7 +12,9 @@`) are not file line numbers after several hunks. Open
  the file at the reviewed ref and read the real line, or every Location in the review is off.
- A hunk that is correct in isolation is the most common way a bug survives review: the caller
  that was not touched is where it breaks. Always `rg` the changed symbol.
- Plans go stale. Code deviating from the document is a finding **only** when the deviation
  changes observable behavior or breaks a stated requirement — a deviation the document's own
  Design decisions already permit is not a finding.
- Anything the document lists under **Out of scope** or as an open question is not a missing
  requirement. Reporting it as one burns the author's trust in the whole review.
- Tests are code: a test asserting the wrong behavior, or one that passes for the wrong reason,
  is a functional finding. A test that is merely ugly is not.
- Generated files (migrations output, API clients, lockfiles, `*.gen.*`) are reviewed by
  reviewing their source and the command that produced them, not line by line.
