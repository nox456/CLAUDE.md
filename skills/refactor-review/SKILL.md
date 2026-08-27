---
name: refactor-review
description: Review changed code for refactor findings — duplication that should become a shared util, helpers that belong in a util file, drift from the repo's own conventions, structure that is hard to read, dead code — reporting each as severity (HIGH/MEDIUM/LOW) + location + description + suggestion + what it improves, and closing with a refactor score. Behavior-preserving only: it never changes what the code does. Runs after the implementation and the code review are both finished, and requires the implementation plan; refuses without one. Report-only: applies no fixes, runs no tests, posts nothing. Use when asked to "refactor review", "review this for refactors", "clean this up", "simplify this", "is this duplicated", "does this follow our conventions", "review the code quality of my changes", or when invoked as /refactor-review. Does not cover bugs or unmet requirements — that is the `code-review` skill's ground, and it runs first.
---

# Review Code for Refactors

Produces a severity-ranked list of **shape** findings in code that already works — duplication
that wants a shared util, helpers that belong in a util file, drift from the repo's own
conventions, structure that is hard to read, dead code — and closes with a refactor score.
Every finding is behavior-preserving: it changes how the code is written, never what it does.
The failure this exists to prevent is a "cleanup" pass that quietly rewrites behavior, or that
invents a style rule the repo never had.

## Ground rules

- **Runs last.** The implementation must be finished and the code review already done
  (step 1 gates on both). Refactoring code that is still being written wastes the review, and
  refactoring code with known bugs in it just relocates them.
- **Same implementation, always.** A finding qualifies only if applying it leaves **observable
  behavior identical** — same outputs, same side effects, same errors, same order. If the fix
  would change what the code does, it is a `code-review` finding: drop it and say so in the
  handoff. This is the exact inverse of `code-review`'s scope rule, and the two must not overlap.
- **Readability beats line count.** Never report a finding whose only benefit is fewer lines.
  A Suggestion that is denser or cleverer than the code it replaces is a regression. Findings
  that *add* lines — a named intermediate, a split function, a named constant — are welcome.
- **A convention must be cited, not felt.** Report convention drift only when you can point at
  its source: a line in `CLAUDE.md`/`AGENTS.md`/a style guide, or **two or more** sibling files
  doing it the other way. An uncited convention is your preference, and preferences are not
  findings.
- **Don't overwhelm.** Extraction has a cost. Apply the thresholds in step 3 literally — a
  duplicated 4-line block is not a finding, and a repo-wide cleanup is not this review's job.
- **Report only.** Edit nothing, write no files, run no formatters or tests, post nothing.
  Findings live in the conversation.
- **Confirm before reporting.** Every finding names code you have actually read at the reviewed
  ref, and every duplication finding names every copy you actually found.
- **The output format is non-negotiable** (step 4). Same six lines, same order, every finding.

## Workflow

- [ ] Step 1 — Confirm the preconditions and load the plan (hard gate)
- [ ] Step 2 — Resolve the scope and learn the repo's conventions
- [ ] Step 3 — Run the four analysis passes
- [ ] Step 4 — Write the findings in the required format
- [ ] Step 5 — Self-review, score, hand off

---

### Step 1 — Confirm the preconditions and load the plan (hard gate)

Two preconditions, both required before any reading starts.

**1. The implementation plan.** Find and read it, in this order:

1. A path the user named.
2. A plan or PRD file in the repo — search by content, not filename:
   ```bash
   rg -l --iglob '*.md' -e '^# PRD' -e 'Implementation Plan' -e 'Acceptance criteria'
   ```
   then check `docs/plans/`, `docs/`, and the repo root.
3. A plan linked from the branch's issue or PR body.

**If there is none, stop.** Say the review cannot start without one, name where you looked, and
offer `/write-implementation-plan`. Do not proceed on the diff alone.

Here the plan is the **scope reference, not the yardstick**: it tells you what was built, which
files and layers are in play, and which patterns the author was told to follow. Requirements
traceability and contract conformance belong to `code-review` and are not re-run here.

**2. The code review.** Ask the user to confirm the code review is finished, unless it visibly
ran earlier in this conversation. If it has not, say so and offer `/code-review` first — a
refactor pass over code with open functional findings reviews a shape that is about to change.
If the user confirms they want to proceed anyway, that is their call: proceed, and note it in
the handoff.

### Step 2 — Resolve the scope and learn the repo's conventions

Pick the scope once and reuse it for every pass:

| The user gave | Scope |
| --- | --- |
| A PR number or URL | `gh pr diff <n>` for the patch, `gh pr view <n>` for metadata |
| Nothing, on a feature branch | `git diff main...HEAD`, plus `git diff HEAD` if the tree is dirty |
| A path or directory | Everything under it that the plan covers |

Never `gh pr checkout` — it moves the user's branch. To read PR files whole:
`git fetch origin pull/<n>/head:pr-<n>`, then `git show pr-<n>:<path>`.

**Then build the convention baseline before judging anything.** You cannot report drift from a
convention you have not established. Spend this pass collecting evidence:

```bash
cat CLAUDE.md AGENTS.md CONTRIBUTING.md 2>/dev/null      # stated rules
ls <dir-of-each-changed-file>                            # file-naming style, existing utils
```

For each changed file, read two or three of its **siblings** — the files next to it doing the
same job. They are the evidence for naming style, file naming, error handling, import style,
and which design patterns this layer already uses. Also locate the util/helper files that
already exist near the change; reusing one always beats creating another.

In an unfamiliar repo, dispatch `Explore` agents per surface rather than reading broadly
yourself.

### Step 3 — Run the four analysis passes

Read `references/analysis-passes.md` now, before writing any finding — it holds the thresholds,
the counting rules, and the traps for each pass.

1. **Duplication and reuse** — copies the change introduced, judged against the size and
   business-rule thresholds, and where a shared util should live.
2. **Module shape and util placement** — first-class modules carrying more than 3 util function
   definitions, and the util file those belong in.
3. **Repo conventions** — naming of variables, functions and files; the design patterns this
   layer already uses; error handling and import style. Evidence required for each.
4. **Readability and cost** — structure that is hard to follow, dead code, and the structural
   performance costs (work in a loop, N+1, repeated work) that a rewrite fixes without changing
   behavior.

Before writing any finding, run the behavior check from that reference: state what the code does
now, what it does after the fix, and confirm they are the same. A finding that fails this check
is dropped.

### Step 4 — Write the findings in the required format

Sort by severity descending, then number from 1. Same six lines each, nothing between them:

```
1. Invoice status labels duplicated across export and card
Severity: HIGH
Location: Multiple locations: packages/api/src/invoices/export.ts:44-58, apps/web/src/InvoiceCard.tsx:12-26
Description: Both sites map the six `InvoiceStatus` members to Spanish labels with their own
copy of the switch, so the next status added lands in one of them and the export silently
prints a raw enum value.
Suggestion: Extract `formatInvoiceStatus(status)` into `packages/shared/src/utils/invoice.ts` and call it from both.
Improving: CodeDuplication

2. `chargeCard` mixes validation, retry and logging in one 80-line body
Severity: MEDIUM
Location: packages/api/src/payments/charge.ts:31-112
Description: Three unrelated concerns are interleaved in one function with four levels of
nesting, so the retry condition is impossible to read without tracing the whole body.
Suggestion: Split out `assertChargeable(payload)` and `withGatewayRetry(fn)`, leaving `chargeCard` as the sequence of the three steps.
Improving: Readability
```

Rules for the fields:

- **Location** — `path:line` or `path:start-end`, taken from the **file at the reviewed ref**,
  never from diff hunk offsets. When one finding spans files, write
  `Multiple locations: <file>, <file>`. Duplication findings are the one case that keeps line
  numbers on each entry, because the copies are the finding: list **every** copy.
- **Description** — 1–2 sentences naming the *shape and what it will cost*, not a restatement of
  the title and not a lecture on the principle.
- **Suggestion** — one line. The concrete move, using the repo's real identifiers and the real
  target path ("extract `X` into `path/to/utils.ts` and call it from both"). Not a patch.
- **Improving** — exactly one label, the primary one:

  | Label | For |
  | --- | --- |
  | `CodeDuplication` | Copies that should share a util |
  | `Readability` | Structure, naming, nesting, altitude — hard to follow as written |
  | `RepoConventions` | Drift from a cited convention: naming, file naming, established pattern |
  | `Modularity` | Util-file moves, misplaced code, module boundaries |
  | `DeadCode` | Unreachable code, unused exports, leftovers from an abandoned approach |
  | `Performance` | A structural cost a behavior-preserving rewrite removes |

  Use one of these six. If a finding needs a seventh label, it is probably out of scope.

Severity anchors — apply these, not intuition:

| Label | Leaving it means |
| --- | --- |
| **HIGH** | It will cause a bug the next time someone touches this code: copies of one business rule that must change together, a convention break that will teach the next author the wrong pattern for a whole layer, or a `Performance` cost on a path that runs per request or per row. |
| **MEDIUM** | Real, repeated friction: a util-file threshold crossed, a genuinely hard-to-follow function on a maintained path, duplication over the threshold that has not diverged yet. |
| **LOW** | Local polish the author can take or leave: naming drift, a small readability win, dead code with no callers. |

If a finding cannot be placed by that table, it is not worth reporting.

### Step 5 — Self-review, score, hand off

Check the draft against `references/review-checklist.md` and fix what fails before showing
anything. Then compute the verdict from the final counts — show the arithmetic:

```
Score = 100 − (15 × HIGH) − (6 × MEDIUM) − (2 × LOW)
Floor at 0.
```

| Score | Verdict |
| --- | --- |
| 90–100 | **Ship as is** — nothing outstanding, or LOWs the author can take or leave |
| 75–89 | **Refactor recommended** — do the HIGHs; MEDIUMs are the author's call |
| 50–74 | **Refactor before merge** — the shape will cost the next person more than the fix costs now |
| 0–49 | **Restructure** — the change works, but it is not in a state to maintain |

Close with, in this order: the counts per severity, the arithmetic line, the score and its band,
and the shortlist of findings worth doing before merge (every HIGH, and nothing else). Then
stop — offer to apply the refactors, re-review after they land, or post the findings to the PR;
do none of them unasked.

## Gotchas

- **This skill replaces `simplify`.** When a sibling skill or the user says to run simplify's
  review phases, run this instead. The built-in `simplify` may still be installed and it
  *applies* edits — that violates this skill's report-only rule.
- Never re-report `code-review`'s findings. Bugs, unmet requirements, contract mismatches and
  broken edge cases are its ground; if you find one here, mention it once in the handoff and do
  not give it a numbered finding or a severity.
- Diff hunk headers (`@@ -12,7 +12,9 @@`) are not file line numbers after several hunks. Open
  the file at the reviewed ref and read the real line.
- **Pre-existing duplication is not this review's ground.** Report a duplicate pair only when
  the change added one of the copies. Otherwise the review turns into a repo-wide audit nobody
  asked for.
- Check the import direction before naming an extraction target. A util placed where a consumer
  cannot import it — or that creates a package cycle — is a worse outcome than the duplication.
- Renaming an **exported** symbol is never a LOW. It touches every call site; either it is a
  HIGH with the blast radius named in the Description, or it is not a finding.
- Tests are in scope, at a higher threshold. Explicit, repetitive test setup is a feature —
  report it only when a fixture or builder already exists and the new tests ignore it.
- Generated files (migration output, API clients, lockfiles, `*.gen.*`) produce no findings.
  Their shape is their generator's business.
- A comment explaining *why* is not dead code. Only comment-out code, unreachable branches, and
  unused exports are.
