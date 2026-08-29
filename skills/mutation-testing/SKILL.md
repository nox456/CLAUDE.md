---
name: mutation-testing
description: Measure whether a test suite actually detects broken code — inject one deliberate defect (a mutant) into the production code at a time, run only the tests covering it, and report which mutants were killed, which survived, and the resulting mutation score. Report-only: it never edits tests, never leaves a mutation on disk, and never fixes a gap it finds. Runs against any suite — the tests `write-tests` just wrote or a pre-existing one — and needs no implementation plan. Use when asked to "run mutation testing", "mutation test this", "are these tests any good", "would the tests actually catch a bug", "do my tests assert anything real", "check the quality of the test suite", "what is our mutation score", or when invoked as /mutation-testing. Does not find untested behavior — that is `write-tests`' coverage audit, which answers a different question.
---

# Mutation-Test an Existing Suite

Coverage says a line ran. Mutation testing says whether anything would have noticed it being
wrong. This skill breaks the production code on purpose, one defect at a time, runs the tests
that should object, and reports every defect the suite let through.

**The output is a report.** Every surviving mutant is a described gap and a named missing
assertion — not a test you write and not a line you fix.

## Ground rules

- **Report, never fix.** No test file is created or edited, no production code is changed
  beyond the mutant that is reverted seconds later. A survivor is a finding; writing the test
  that kills it is `write-tests`' job and the user's call.
- **Green baseline or stop** (step 2). If the suite is red before you mutate anything, every
  result is uninterpretable — a mutant "killed" by a test that was already failing proves
  nothing.
- **One mutant at a time, never stacked.** Two live mutants can mask each other, and neither
  result can be attributed. Apply, run, revert, then move to the next.
- **Restore from a snapshot, never from git.** `git checkout -- <file>`, `git stash` and
  `git restore` destroy the user's uncommitted work. `scripts/mutant-guard.sh` copies the
  in-scope files first and restores from those copies.
- **Verify the restore after every single mutant.** A mutant left on disk is the one way this
  skill can do real damage. `verify` must print `OK` before the next mutant is applied; if it
  does not, stop the entire run and tell the user which file is dirty.
- **Never mutate a test file, a fixture, a factory, or a config.** Mutating a test asks whether
  the test tests itself. Mutate production source only.
- **A survivor is a hypothesis until classified** (step 5). Equivalent mutants — edits that
  cannot change observable behavior — are not gaps, and reporting them as gaps is how a
  mutation report loses its reader.
- **Cap the run before it starts.** Cost is (mutants × suite runtime). Agree the budget with
  the user at step 3 rather than discovering it at mutant 60.

## Workflow

- [ ] Step 1 — Resolve the mutation surface
- [ ] Step 2 — Derive the test command and prove the baseline is green (hard gate)
- [ ] Step 3 — Plan the mutants and get approval (gate)
- [ ] Step 4 — Run the mutation loop
- [ ] Step 5 — Classify the survivors
- [ ] Step 6 — Report
- [ ] Step 7 — Hand off

---

### Step 1 — Resolve the mutation surface

Resolve the scope once and reuse it everywhere:

| The user gave | Scope |
| --- | --- |
| Nothing, on a feature branch | `git diff main...HEAD --name-only`, plus `git diff HEAD --name-only` if the tree is dirty |
| A PR number or URL | `gh pr diff <n> --name-only` — never `gh pr checkout`, it moves the user's branch |
| A path or directory | Every production source file under it |
| A test file ("mutation test what write-tests wrote") | The production files that test file imports — read its imports, do not guess from the filename |

Drop test files, fixtures, factories, mocks, config, generated code and vendored code from the
list. What remains is the **mutation surface**; state its file count before going further.

Then record the starting state — the report cites both, and a dirty tree changes what the
snapshot in step 4 is protecting:

```bash
git status --porcelain                                             # was the tree already dirty?
rg -n '\.only\(|fdescribe|fit\(|xit\(|\.skip\(' <test-files>      # see the gotchas
```

### Step 2 — Derive the test command and prove the baseline is green (hard gate)

Read `references/scoped-test-runs.md` now — it holds the per-runner flags for scoping a run to
one file or one directory, the flags that must never be used (watch, snapshot-update, bail), and
how to handle a monorepo where the runner lives in the package rather than the root.

You want the smallest command that still runs **every** test capable of killing a mutant in the
surface. Too narrow and mutants survive for the wrong reason; too wide and the run costs hours.
Verify the command reruns the tests you expect by checking its reported test count against the
baseline's.

Then run it, clean, and **gate on the result. If the baseline is red, stop.** Report which
tests fail and say mutation testing cannot start until they pass — a mutant "killed" by a test
that was already failing proves nothing. Do not work around a failing test by excluding it: that
silently removes the only assertions guarding part of the surface.

Record the run's passing test count and wall-clock runtime. Both are used later — the count is
what distinguishes a real kill from a collapsed suite in step 4, and the runtime sets both the
per-mutant timeout and the budget estimate in step 3.

If some file in the surface has no test running against it at all, record it now as **NO
COVERAGE**. Do not plan mutants for it — an uncovered line's mutants all survive trivially and
say nothing beyond "this is untested", which is `write-tests`' finding, not this one's.

### Step 3 — Plan the mutants and get approval (gate)

Read `references/mutation-catalog.md` before choosing a single edit — it holds the operators,
the rule for picking the ones that matter per layer, and the edits that are equivalent by
construction and must never be planned.

Plan **highest-risk first**: the lines where a silent defect moves money, loses or corrupts
data, opens a permission hole, or breaks a production path. A mutation run cut short after ten
mutants should already have tested the ten that matter.

Fill `assets/mutation-ledger.md` and write it to the scratchpad directory. It is the run's
recovery record: if the session dies mid-loop, it names exactly which file was mutated and
what the edit was.

Then **stop and show the user** the ledger, the mutant count, and the estimated cost
(`mutants × baseline runtime`). Default budget is **20 mutants or 10 minutes, whichever comes
first** — say so, and let them raise it, lower it, or re-aim it. Do not start the loop until
they answer.

### Step 4 — Run the mutation loop

Snapshot once, before the first mutant:

```bash
bash scripts/mutant-guard.sh snapshot <every file in the mutation surface>
```

Then, for each mutant in ledger order, exactly this sequence — no batching, no reordering:

```bash
# 1. apply ONE edit from the ledger to ONE file
# 2. run the scoped command under a timeout of ~3x the baseline runtime
timeout 90 <scoped test command>; echo "exit=$?"
# 3. restore and verify BEFORE recording anything
bash scripts/mutant-guard.sh restore
bash scripts/mutant-guard.sh verify        # must print OK
# 4. write the result into the ledger row
```

If `verify` does not print `OK`, **abort the whole run** and tell the user which file differs
from its snapshot. Do not attempt another mutant.

Map the run to a result by reading the failure output, not the exit code alone:

| What happened | Result |
| --- | --- |
| Suite green, same test count as baseline | **SURVIVED** |
| One or more tests failed on an **assertion** | **KILLED** — record the first failing test's `path:line` and name |
| Exit 124 / the runner hung | **TIMEOUT** — counts as killed (an infinite loop is a detected defect), but listed separately |
| A compile, type, import or syntax error | **INVALID** — the mutant was never valid code. Excluded from the score; replace it with another mutant if budget allows |
| Suite green but the test count collapsed | **INVALID** — the mutant broke collection. Investigate before continuing |

Never credit a kill to a test that was not passing in the baseline.

### Step 5 — Classify the survivors

Read `references/survivor-analysis.md` before writing a single finding — it holds the test for
equivalence, the four reasons a mutant survives, and how to derive the one missing assertion
that would have killed it.

For each survivor decide, in this order:

1. **Equivalent?** Could this edit change any observable output, persisted row, emitted event or
   thrown error? If no, mark **EQUIVALENT**, give the one-line reason, and exclude it from the
   score. Do not report it as a gap.
2. **Unreachable?** If no input can reach the mutated line, the finding is dead code, not a test
   gap. Report it as such.
3. Otherwise it is a **real gap**. Name the assertion that was missing, concretely enough to
   write: *"after a failed charge, the `attempts` table holds exactly one row for that charge
   id"* — not "add a test for the retry path".

Assign severity with these anchors, not intuition:

| Label | A defect here slipping through means |
| --- | --- |
| **HIGH** | Money moves wrongly, data is lost or corrupted, a permission hole opens, or a production path breaks — and the entire suite stays green. |
| **MEDIUM** | A path users hit degrades rather than breaks, and nothing objects. |
| **LOW** | A narrow input, a defensive guard, or a value the suite checks the shape of but not the content of. |

### Step 6 — Report

Print this to the conversation. Write no file, edit no plan.

```
### Mutation report — <scope>

Baseline: 42 tests passing · `pnpm vitest run src/payments` · 3.1s · tree was clean
Surface: 4 files · 18 mutants planned, 18 run

| # | File:line | Operator | Mutation | Result | Killed by |
| --- | --- | --- | --- | --- | --- |
| M-1 | charge.ts:88 | conditional-boundary | `attempts >= max` → `attempts > max` | KILLED | `charge.test.ts:31` "stops after 3 attempts" |
| M-2 | charge.ts:94 | call-removal | removed `await recordAttempt(id)` | SURVIVED | — |
| M-3 | export.ts:22 | negate-conditional | `if (inv.voided)` → `if (!inv.voided)` | SURVIVED | — |
| M-4 | fx.ts:14 | arithmetic | `a * rate` → `a / rate` | EQUIVALENT | — |

Killed 12 (incl. 1 timeout) · Survived 3 · Equivalent 1 · Invalid 2 · No coverage 1 file
Mutation score = 12 / (12 + 3) = 80%

1. Nothing asserts the retry attempt is recorded
Severity: HIGH
Mutant: M-2 — `packages/api/src/payments/charge.ts:94`, `await recordAttempt(id)` removed
Survives because: every case in `charge.test.ts` asserts on the returned receipt only; the
attempts table is never read back, so dropping the write changes nothing the suite looks at.
Missing assertion: after a failed charge, `attempts` holds exactly one row for that charge id.

2. ...

Not covered: `packages/api/src/payments/refund.ts` — no test runs against it; not mutated.
```

Rules for the fields:

- **Mutation** — the before and after, as source, short enough to read in one glance.
- **Killed by** — the test's `path:line` and its own name, taken from the runner's output. "the
  suite" is not an answer; if you cannot name the test, the result is not a confirmed kill.
- **Survives because** — what the suite looks at instead. Not a restatement of the mutation.
- Sort findings by severity descending and number from 1. Every SURVIVED row gets a finding.

**Show the arithmetic.** `killed / (killed + survived)`, with timeouts counted as killed and
equivalent, invalid and no-coverage mutants excluded from both sides. This is not a line-coverage
number and does not replace one — say so if the repo reports coverage too.

### Step 7 — Hand off

Report, compactly: the mutation score with its arithmetic, the survivors ranked by severity, the
files excluded as NO COVERAGE, whether the tree was dirty when you started, and — stated plainly
— that every mutation has been reverted and `verify` passed.

Then stop. Writing the missing tests (`/write-tests`), raising the budget for a deeper run, and
mutating the files reported as uncovered are all good next steps — offer them, do not do them
unasked.

## Gotchas

- **`git checkout`, `git restore` and `git stash` are not safe here.** On a dirty tree they
  delete work the user has not committed. Restore only through `scripts/mutant-guard.sh`, which
  restores the file as it was when the run started, committed or not.
- **A watch-mode command never exits and hangs the run forever.** Always the run/CI form:
  `vitest run`, `jest --ci --watchAll=false`, `pytest` (not `-f`), `go test` (not `-race -count`
  loops). Confirm the command terminates during the step 2 baseline run before relying on it.
- **A stray `.only` / `fdescribe` / `fit` makes almost every mutant survive**, because the
  scoped command is really running one test. Grep for it in step 1; if one is present, say so
  and stop — the baseline's test count is a lie.
- **A type or compile error is INVALID, not KILLED.** In a typechecked repo the runner exits
  non-zero for a mutant that never compiled, which looks identical to a kill from the exit code.
  Read the output and classify on the failure kind, always.
- **Snapshot tests silently absorb mutants.** If the runner is configured to write snapshots
  when they are missing, or if anyone passes `-u`, the mutant updates the snapshot and survives.
  Never run with the update flag, and treat a snapshot-only assertion as weak evidence of a kill.
- **A coverage threshold in the runner config fails the run for reasons unrelated to the
  mutant.** Check whether the failure is a threshold before recording a kill.
- **A suite sharing a database or a filesystem must be run serially.** With parallel workers, a
  row left behind by the previous mutant's run kills the next one, and the attribution is wrong.
- **Transpile and module caches can serve the pre-mutation file.** If two different mutants in
  the same file produce byte-identical runner output, suspect the cache before believing the
  result — clear it or add the runner's no-cache flag and rerun both.
- **A flaky test looks like a kill.** If one test name kills mutants in files it does not import,
  it is flaking, not detecting. Rerun that mutant once; if the kill does not reproduce, record it
  as SURVIVED and flag the flake.
- **In a monorepo the runner, its config and its path aliases live in the package**, not the
  root. Run the scoped command from the package directory that owns the mutated file.
- **Mutating logging, telemetry, comments or a `catch` block that only re-throws is wasted
  budget** — those are equivalent by construction. `references/mutation-catalog.md` lists the
  full set to skip.
