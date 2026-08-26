# The four analysis passes

Read at the start of step 3, before writing any finding. Work the passes in order — 1 and 2
are the ones a review without the document cannot perform, and they surface the findings that
matter most (code that runs fine and ships the wrong thing).

## Before you write any finding: confirm it

A finding is a claim about what the code does at runtime. Confirm it the cheap way first:

1. Read the **whole** function at the reviewed ref, not the hunk.
2. `rg` the symbol for every caller — most confirmations and most retractions live there.
3. Read the tests covering the path (do not run them). A test that asserts the opposite of
   your claim usually means you misread the code; a test that asserts the buggy behavior is
   itself a finding.
4. Check `git log -S'<symbol>'` when the code looks deliberately odd — it often encodes a fix
   for a case you are about to "fix" back.

If it is still unconfirmed after that: drop it, or keep it and say so in the Description
("if `queue.flush()` can run concurrently — I could not confirm from the call sites — then …").
Never inflate an unconfirmed suspicion to HIGH or BLOCKING.

## Pass 1 — Requirement traceability

Walk the document's numbered requirements and acceptance criteria **one by one**. For each,
find the code that satisfies it and assign one of:

| Verdict | Finding? |
| --- | --- |
| Implemented | No |
| Partial — works for the main case, a stated sub-case is missing | Yes, usually MEDIUM |
| Missing — nothing implements it | Yes, BLOCKING |
| Contradicted — the code does something the document rules out | Yes, BLOCKING or HIGH |

Also check the inverse: **behavior in the code that no requirement asked for.** New endpoints,
new writes, new outbound calls, new stored fields. Unrequested behavior is either a scope leak
or a leftover from an abandoned approach, and it is where unreviewed risk hides.

Given/When/Then acceptance criteria are the highest-yield input here: read each as a test case
and trace whether the code would actually produce the Then.

## Pass 2 — Contract conformance

The document's **Contracts** section states what parallel work depends on. Diff it against
reality, in both directions:

- **Shape** — field names, optionality, nullability, units, enum members, date encoding
  (string vs. Date vs. epoch), money representation (minor units vs. decimal).
- **Signature** — parameter order and types, return type, thrown vs. returned errors, sync
  vs. async.
- **Error contract** — the codes and messages consumers are told to expect, and whether a
  failure surfaces as an exception, a null, or a silent default.
- **Persistence** — DDL vs. the migration actually written: column types, nullability,
  defaults, unique and foreign keys, index coverage for the queries the plan introduces.
- **Caller/callee agreement** — every call site of a changed signature, every consumer of a
  changed payload, every reader of a changed column.

A contract mismatch that type-checks (same type, different meaning — seconds vs. milliseconds,
gross vs. net, id vs. external id) is the highest-severity variant of this class, because
nothing downstream will catch it.

## Pass 3 — Behavior under stress

Probe the changed code against the classes below. This is a hunting list, not a checklist to
report against — only confirmed hits become findings.

- **Order of operations** — validation after the write; state mutated before the check that
  guards it; the audit log written before the transaction that may roll back.
- **Async and concurrency** — a missing `await`; a promise created in a loop and never awaited;
  read-modify-write without a lock or a conditional update; two requests racing the same row;
  a debounce or cache stampede on a hot path.
- **Error paths** — a `catch` that swallows and continues with a half-built object; a retry
  around a non-idempotent operation; a fallback value that is indistinguishable from a real
  one; cleanup that only runs on the success path.
- **Boundaries and empties** — `0`, `-1`, `""`, empty array, single-element array, exactly the
  page size, one past it; off-by-one in slicing and pagination; `null` vs. `undefined` vs.
  missing key; falsy checks (`if (count)`) where `0` is legal.
- **Idempotency and retries** — what a duplicate delivery, a double click, or a job retry does
  to state; whether the idempotency key covers everything the operation writes.
- **Transactions** — writes to two stores with no way to reconcile a partial failure; a commit
  that leaves a queue message unsent, or a message sent before the commit.
- **Permissions and tenancy** — an endpoint or query that skips the ownership filter; an id
  taken from the request body rather than the session; an admin path reachable without the
  check the document specifies.
- **Time and locale** — timezone assumed from the server; DST arithmetic; date-only values
  crossing a timezone; sorting or comparing formatted strings instead of values.
- **Cache and flags** — a write path that does not invalidate what a read path caches; the
  flag-off branch never exercised; the code behaving differently on a cold cache.

## Pass 4 — Blast radius on untouched code

The change is correct; what did it break elsewhere?

- Existing callers of every changed signature, default, or return convention.
- Rows already written by the old code: does the new read path handle them, or does the plan's
  backfill cover them? Run the migration's logic mentally against a pre-existing row.
- The compatibility window in the document: deployed clients, in-flight jobs, queued messages,
  and cached payloads produced by the old code must all still work during the rollout.
- The rollback path: if this is reverted after the migration ran, what breaks — and does the
  document's stated rollback actually restore a working state?
- Feature flag off: the old path must still work, unchanged, for as long as the flag exists.
