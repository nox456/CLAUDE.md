# Building the behavior inventory

Read at Step 2, before classifying anything. The audit is only as good as this list: a behavior
you never wrote down cannot be reported as a gap, and the coverage percentage is a fraction of
this list's length.

## What counts as a behavior

One behavior = **one input condition producing one observable outcome**. Not one function, not
one file. A function with three branches that return different payloads is three behaviors.

Write each as a sentence with a subject and an outcome — "a voided invoice is excluded from the
export", not "the export filter". If you cannot phrase the outcome, you are describing
implementation and it does not belong on the list.

Cap the inventory at what the change touched. A behavior the diff did not add or alter belongs
to the pre-existing suite, however untested it is.

## Where they come from

Work both ends and merge:

**From the plan** — every numbered technical requirement, every acceptance criterion, every
shape in **Contracts** (a required field, a status code, an enum's members, a DDL constraint),
and every failure the migration/rollout section names. A requirement that maps to no behavior
means the plan and the code disagree — report it as a finding.

**From the diff** — read each changed function whole, not the hunk. Then probe by layer:

| Layer | Probe for |
| --- | --- |
| Pure logic / helpers | Each branch, each early return, each boundary in a comparison, each thrown error |
| API handlers | Each status code, validation rejections, the auth/permission check, the response body shape |
| Database / repository | Filter and ordering clauses, the empty result, uniqueness and FK violations, transaction rollback, soft-delete filters |
| Jobs / async | Retry and its limit, the same message delivered twice, partial failure mid-batch, what is left behind on abort |
| Frontend | Each rendered state (loading, empty, error, populated), each user action, disabled and permission-gated affordances |
| Shared contracts / types | Each schema rejection, each optional field defaulting, backward compatibility with the old shape |

Then add the cross-cutting ones the layer tables miss: idempotency (the same call twice),
concurrency (two callers at once), ordering, timezone and locale, and what a failure leaves
persisted.

## Finding the test that covers a behavior

Search, then **read the test body**. A filename is not evidence.

```bash
rg -n --iglob '*{test,spec}*' '<symbol-under-test>'   # tests importing the changed symbol
rg -n --iglob '*{test,spec}*' '<a distinctive string, error code, or field name>'
```

A test covers a behavior only when all three hold:

1. It exercises the changed code path — not a sibling branch that happens to share a name.
2. It asserts the behavior's **outcome**, on a value the test itself constructed.
3. It would **fail** if the behavior regressed. Ask this explicitly: change the behavior in your
   head, and see whether an assertion breaks.

## Covered / Partial / Uncovered

| Status | When |
| --- | --- |
| **Covered** | All three conditions hold. The test names the case and asserts the outcome. |
| **Partial** | The path runs but the assertion is weaker than the behavior: shape asserted without values, one of several branches covered, the outcome checked but not the side effect, or the case is only reached incidentally by a test aimed elsewhere. |
| **Uncovered** | No test reaches the path, or the only tests that do assert nothing that would break. |

Partial counts as 0.5 in the percentage, and still gets a gap entry with its own severity.

## Traps

- **The test that passes for the wrong reason.** A mocked collaborator returning `undefined`
  satisfies most loose assertions; the path was never really exercised. Check what the mock
  returns before crediting the test.
- **The name that lies.** `it("handles errors")` that asserts only "did not throw" covers
  nothing. Read the assertions, never the test title.
- **The shared setup that already covers it.** A `beforeEach` seeding the exact state, plus one
  assertion downstream, can be real coverage. Read the whole file before marking Uncovered.
- **Type-level guarantees are not behaviors.** A field the compiler makes impossible to omit
  does not need a runtime test; a field a validator rejects at the boundary does.
- **A behavior the plan lists under Out of scope or as an open question is not a gap.** Reporting
  it as one burns trust in the whole audit.
- **Generated code** (migration output, API clients, `*.gen.*`) contributes no behaviors. Test the
  code that consumes it.
