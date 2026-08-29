---
name: write-tests
description: Write the tests for a change that is already implemented — audit behavior by behavior what the existing suite covers, report each gap as HIGH/MEDIUM/LOW with a coverage percentage, write unit tests that always carry happy path, edge cases and error path, offer flow-based integration tests, then append a "Test coverage" section to the implementation plan. Requires a finished implementation plan and the code already implemented; refuses without both. Writes test files but never runs them and never edits production code. Use when asked to "write tests", "write unit tests for this", "add test coverage", "cover this with tests", "test this feature", "what is our test coverage", "are these changes covered", or when invoked as /write-tests. Runs after `implementation-loop`, which deliberately writes no tests.
---

# Write Tests for an Implemented Change

Closes the gap the rest of the pipeline leaves open: `write-implementation-plan` specifies no
tests and `implementation-loop` writes none, so the change lands working and uncovered. This
skill measures what the suite already covers, writes the tests that are missing, and records
the result back in the plan.

**Audit first, then write.** The audit is what makes the writing selective — without it every
run produces the same three tests per function regardless of what the suite already had.

## Ground rules

- **Plan and implementation, both required.** Step 1 gates on a finished implementation plan
  *and* code that exists. Tests written against a plan alone assert signatures that were never
  built.
- **Test observable behavior, never implementation.** Assert on returned values, persisted
  rows, emitted events, thrown errors, and rendered output. A test whose only assertion is that
  a mock was called is not coverage — it locks in the current call graph and fails on a
  behavior-preserving refactor.
- **Three categories, every group, always.** Every unit test group covers happy path, edge
  cases and error path (step 3). When a category genuinely has nothing to test, it is written as
  a one-line stated reason inside the group — never silently dropped.
- **Never touch production code.** If a behavior is untestable as written, or the code
  contradicts the plan, that is a finding to report, not a diff to make. Report it and move on;
  fixing it is `code-review`'s ground and the user's call.
- **Never write a test around a bug.** When the code's real output contradicts what the plan
  specifies, assert what the **plan** specifies, mark the test with the repo's skip/todo idiom,
  and report it as an expected failure. Asserting the buggy output makes the suite defend it.
- **Do not run the suite.** The user runs the tests. That makes step 5 non-optional: nothing
  else catches a typo'd import or a signature that does not exist.
- **Ask before integration tests, always** (step 4). Never assume, in either direction.
- **Scope is the change, not the repo.** Behavior the change added or altered is in scope.
  Pre-existing untested code is not a gap this audit reports.

## Workflow

- [ ] Step 1 — Confirm the preconditions and load the plan (hard gate)
- [ ] Step 2 — Audit the existing coverage, behavior by behavior
- [ ] Step 3 — Write the unit tests
- [ ] Step 4 — Offer integration tests, then write them if asked
- [ ] Step 5 — Static verification and self-review (gate)
- [ ] Step 6 — Append "Test coverage" to the plan
- [ ] Step 7 — Hand off

---

### Step 1 — Confirm the preconditions and load the plan (hard gate)

**1. The implementation plan.** Find and read it, in this order:

1. A path the user named.
2. A plan file in the repo — search by content, not filename:
   ```bash
   rg -l --iglob '*.md' -e 'Implementation Plan' -e '^## Build sequence' -e 'Technical requirements'
   ```
   then check `docs/plans/`, `docs/`, and the repo root.
3. A plan linked from the branch's issue or PR body.

**If there is none, stop.** Say the tests cannot be written without one, name where you looked,
and offer `/write-implementation-plan`. Do not proceed on the diff alone: without the numbered
requirements and the Contracts section there is no standard for what the tests should assert,
and the run degrades into restating the code back at itself.

What to extract: the numbered technical requirements, the **Contracts** section, **Design
decisions** (what was deliberately rejected must not be tested for), **Out of scope** and open
questions (these bound what may be reported as a gap), and the build sequence.

**2. The implementation.** Confirm the code exists — the plan's artifacts are on disk and the
build sequence is marked done. If the plan is written but unimplemented, stop and offer
`/implementation-loop` first. A partially implemented plan is workable: audit and test only the
phases marked done, and say which phases you skipped.

Then resolve the scope once and reuse it for every step:

| The user gave | Scope |
| --- | --- |
| Nothing, on a feature branch | `git diff main...HEAD`, plus `git diff HEAD` if the tree is dirty |
| A PR number or URL | `gh pr diff <n>` — never `gh pr checkout`, it moves the user's branch |
| A path or directory | Everything under it that the plan covers |

### Step 2 — Audit the existing coverage

Read `references/behavior-inventory.md` now — it holds the per-layer probes for enumerating
behaviors, the rules for deciding Covered / Partial / Uncovered, and the traps that make a test
look like coverage when it is not.

Three passes: enumerate the behaviors the change introduced or altered → find the test that
exercises each one → classify what is missing.

Report it in exactly this shape:

```
### Coverage audit — <scope>

| # | Behavior | Source | Existing test | Status |
| --- | --- | --- | --- | --- |
| B-1 | Voided invoices are excluded from the CSV export | TR-4 · exportInvoices.ts:31 | `export.test.ts:12` "filters by status" | Covered |
| B-2 | A gateway timeout after authorization does not re-charge | TR-7 · charge.ts:88 | — | Uncovered |
| B-3 | Empty result set writes a header-only file | charge.ts:140 | `export.test.ts:44` asserts row count only | Partial |

1. The retry path can re-charge a card and nothing tests it
Severity: HIGH
Behavior: B-2
Location: packages/api/src/payments/charge.ts:88-112
Why it matters: the idempotency key is the only thing preventing a double charge, so a
refactor that drops it regresses silently into production.

Coverage = (5 covered + 0.5 × 2 partial) / 14 behaviors = 43%
Gaps: HIGH 3 · MEDIUM 4 · LOW 2
```

Rules for the fields:

- **Source** — the requirement ID the behavior comes from and the `path:line` implementing it.
  A behavior with neither is one you inferred; say so or drop it.
- **Existing test** — `path:line` and the test's own name, from a test you have opened and read.
  A filename that merely looks related is not evidence.
- **Why it matters** — the consequence of the regression going unnoticed. Not a restatement of
  the behavior, not a lecture on testing.
- Sort the gaps by severity descending and number from 1. Partial behaviors get a gap entry too.

Severity anchors — apply these, not intuition:

| Label | Leaving it uncovered means |
| --- | --- |
| **HIGH** | A regression here loses or corrupts data, moves money wrongly, opens a permission hole, or breaks a production path — and no other test in the suite would fail. A numbered requirement with no test at all is always at least HIGH. |
| **MEDIUM** | A path users hit, uncovered or covered only incidentally, where a regression degrades behavior rather than breaking it. |
| **LOW** | A narrow input, a defensive guard, or a behavior asserted weakly (shape checked, value not). |

**Show the arithmetic.** Coverage is `(covered + 0.5 × partial) / total`, rounded to a whole
percent. This is a behavior count, not a line-coverage number — if the repo has a coverage tool,
its percentage answers a different question; do not substitute it.

Present the audit and **stop for the user** before writing anything. They may want only the
HIGHs covered, and a full sweep is expensive to throw away.

### Step 3 — Write the unit tests

Read `references/test-conventions.md` before creating the first file — it is how you find the
framework, the file location and naming, the factories and helpers that already exist, and the
mocking boundary this repo has settled on. Reusing them matters more than any structure below.

**Write in severity order**, highest gap first, so a run that gets cut short has already
delivered the tests worth having.

One group per unit under test — a function, a module, an endpoint, a component. Every group
carries all three categories, mirrored in the repo's own grouping idiom:

```
describe("<unit under test>", () => {
  describe("happy path", () => {
    // the behavior as the plan specifies it, with realistic values.
    // at least one case per numbered requirement this unit carries.
  })

  describe("edge cases", () => {
    // boundaries (0, 1, max, one over), empty / null / missing / undefined,
    // duplicates, ordering, the same input applied twice (idempotency),
    // legal-but-unusual input: unicode, negative, very large, other timezone.
  })

  describe("error path", () => {
    // each way it can fail: invalid input rejected with the error the plan names,
    // a dependency that throws / rejects / times out / returns non-200,
    // permission denied — and that a failure leaves no partial write behind.
  })
})
```

Per case: one behavior, a name that states the behavior and its outcome (not "works
correctly"), and the arrange/act/assert shape the repo's existing tests use. Build inputs with
the repo's factories; assert on values you constructed, so the test fails when the behavior
changes.

If a category is genuinely empty — a pure formatter with no failure mode — say so in one line
inside the group rather than deleting it: `// error path: none — the function is total.`

### Step 4 — Offer integration tests, then write them if asked

**Always ask, with `AskUserQuestion`**, once the unit tests are written and never before — the
answer depends on what the units already cover. Name the flows you would test and their cost.
If the answer is no, say so in step 6's plan section and skip to step 5.

An integration test covers **a feature's flow, end to end**, not a function. One test per
user-visible flow, built from the plan's build sequence in order:

```
test("<actor> <does the flow> and <the observable outcome>", ...)
  Arrange — the state the flow starts from, seeded through the repo's factories
  Act     — the steps in order, each through its real entry point:
            the route handler, the job, the command — never the internal function
  Assert  — the observable outcome at every seam the plan names:
            persisted row, emitted event, response payload, external call made
```

Use the real collaborators wherever the repo's existing integration tests use them. Mock only
what crosses the process boundary the repo already mocks — the payment gateway, the mailer, the
clock. A flow test with everything mocked tests the mocks.

Also cover the flow's principal failure: one test where a mid-flow step fails, asserting the
state it leaves behind is the one the plan specifies.

### Step 5 — Static verification and self-review (gate)

Nothing here executes the tests, so this pass is the only thing between you and a suite that
does not even load. Read `references/review-checklist.md` and work it line by line.

The non-negotiable half, for **every** file written:

```bash
rg -n '^(import|const .* = require|from )' <test-file>   # every import
ls <resolved-path>                                        # the file exists
rg -n 'export (function|const|class) <symbol>' <source>   # the symbol exists, spelled that way
```

Then confirm each call site matches the real signature — arity, argument order, sync vs. async,
what it returns — by reading the source, not by recall. Fix everything you find before showing
the tests. State plainly in the handoff that the suite has not been run.

### Step 6 — Append "Test coverage" to the plan

Fill `assets/test-coverage-section.md` and append it to the plan file, after the Verification
section. Do not restructure the document, do not edit sections other than the `Updated:` date,
and do not delete the plan's "no test planning" note — it stayed true for the plan.

Record both numbers: the coverage before this run and after it, with the same arithmetic. A gap
left deliberately uncovered stays in the table with its severity and one line of why, so the
next reader knows it was a decision and not an oversight.

### Step 7 — Hand off

Report, compactly: the files written and how many cases each holds, coverage before → after
with the arithmetic, the gaps still open ranked by severity, any expected-failure test and the
bug behind it, whether integration tests were written or declined, and — stated plainly — the
command the user should run, and that you did not run it.

Then stop. Running the suite, fixing the bugs the audit surfaced, and the closing reviews are
good next steps — offer them, do not do them unasked.

## Gotchas

- **A new snapshot always passes.** Writing one records current behavior, bugs included, and
  asserts nothing about what the plan requires. Use snapshots only where the repo already does,
  and never as the coverage for a numbered requirement.
- **A mock returning `undefined` makes weak assertions pass forever.** `expect(x).toBeUndefined()`
  and `expect(x).toBeDefined()` on a mocked path test the mock. Assert values you constructed.
- **Asserting a mock's call count is not a behavior test.** It is allowed only as a *second*
  assertion, next to one on the observable outcome, and only where the call itself is the
  behavior (an email was sent, the gateway was charged once).
- Time, randomness, and generated IDs are the flake sources. Freeze them with the helper the
  repo already has; if it has none, inject the value rather than inventing a global mock.
- In a monorepo the runner config, setup files, environment (`node` vs `jsdom`) and path aliases
  are **per package**. A test placed in the wrong package silently never runs.
- A test file that mirrors the source path but is excluded by the runner's `include` glob is
  invisible — check the glob, not just the directory.
- Never delete, skip, or weaken an existing test to make a run look green. An existing test that
  fails is a finding for `code-review`, and it is out of this skill's scope.
- Coverage tooling reports lines executed, not behaviors asserted. A file at 100% lines can have
  every gap this audit reports still open.
- Do not add a test that duplicates one the audit already marked Covered — the audit exists
  precisely to prevent that.
