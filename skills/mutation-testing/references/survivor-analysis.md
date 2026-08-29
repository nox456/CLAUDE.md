# Classifying a survivor

Read at Step 5, before writing findings. A raw survivor list is noise; the value of the report
is entirely in this pass. Every survivor gets classified, and only the real gaps become findings.

## First: is it equivalent?

An **equivalent mutant** is a change that no possible input can make observable. It survives
because there is nothing to detect, so it is not a test gap and must never be reported as one.

Apply this test, in order — the first "yes" ends it:

1. Can the mutated expression's two versions ever produce different values for an input the
   function can actually receive? (`x >= 0` vs `x > 0` on a value proven non-zero upstream: no.)
2. If they can differ, does that difference reach anything observable — a return value, a
   persisted row, an emitted event, a rendered node, a thrown error, an outbound call?
3. If it reaches an observable, is that observable ever produced under a reachable code path?

If you answer "no" at any step, mark **EQUIVALENT**, record the one-line reason, exclude it from
the score, and move on. If you cannot decide in about a minute, do **not** guess: mark it as a
real gap and say in the finding that equivalence was not ruled out. An over-reported gap costs
the user a minute; a wrongly dismissed one costs them the bug.

## Then: why did it really survive?

| Reason | What you will see | What to report |
| --- | --- | --- |
| **No assertion on the effect** | Tests call the code and assert on the return value, but the mutated line writes, emits, or invalidates something nothing reads back | A real gap. Name the effect and where to observe it |
| **Assertion too weak** | The test asserts shape, truthiness, length, or `toBeDefined()` where the mutation changes the value | A real gap. Name the exact value the assertion should pin |
| **Input never reaches the branch** | Every test uses inputs on one side of the boundary | A real gap. Name the input that would cross it |
| **Unreachable in production too** | No caller anywhere can produce an input reaching the line | Dead code, not a test gap. Report it as such and do not count it as a gap |

The fourth row is worth the check: mutation testing is one of the few things that finds dead
code by accident. Confirm with a call-site search before claiming it.

## Deriving the missing assertion

The finding is only useful if the reader can write the test from it. Turn the mutant into an
assertion mechanically:

> The mutation changed **X** into **Y**. A test that fails under **Y** must observe **the thing
> that differs**. What is it, and where can it be seen?

- `attempts >= max` → `attempts > max` survived
  → *"a fourth attempt is not made once `max` is 3"* — a case sitting exactly on the boundary.
- `await recordAttempt(id)` removed and it survived
  → *"after a failed charge, `attempts` holds exactly one row for that charge id"* — the test
  must read the table, which today it never does.
- `if (invoice.voided)` negated and it survived
  → *"a voided invoice is absent from the export while an open one is present"* — the fixture
  needs both, and today it has only one.

Write it as the assertion, in the repo's own domain vocabulary. Never write "add a test for the
retry path" — that is the gap restated, not the fix.

## Grouping

Several survivors often share one root cause — a whole module tested only through its return
value, one fixture that never crosses a boundary. Report the root cause once, list the mutants
it explains, and give the severity of the worst one. Ten findings that say the same thing get
skimmed; one finding with ten mutants attached gets acted on.

## Weighing the score

State the score, then say what it is not. A mutation score is the fraction of injected defects
this suite detected **in the sampled surface** — a sample you chose, biased deliberately toward
risky lines. It is not comparable to a tool's exhaustive score, it does not go up or down with
line coverage, and it should never be reported as a repo-wide number from a scoped run.
