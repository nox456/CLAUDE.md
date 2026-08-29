# Mutation ledger — <scope>

Written at Step 3, before the first mutant is applied; updated after every loop iteration in
Step 4. Lives in the scratchpad, never in the repo. If the session dies mid-run, this file names
the file that may still be mutated and the exact edit to undo.

Baseline: <n> tests passing · `<scoped test command>` · <runtime>s · tree was <clean|dirty>
Snapshot store: <path printed by `scripts/mutant-guard.sh snapshot`>
Budget: <n> mutants / <n> minutes, approved by the user

Status values: PENDING → APPLIED → RESTORED, then the result
(KILLED · SURVIVED · TIMEOUT · INVALID · EQUIVALENT).
A row left at APPLIED is a mutation still on disk — restore it before anything else.

| # | File:line | Operator | Before | After | Status | Result | Killed by |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M-1 | src/payments/charge.ts:88 | conditional-boundary | `attempts >= max` | `attempts > max` | RESTORED | KILLED | `charge.test.ts:31` "stops after 3 attempts" |
| M-2 | src/payments/charge.ts:94 | call-removal | `await recordAttempt(id)` | *(removed)* | RESTORED | SURVIVED | — |
| M-3 | src/payments/export.ts:22 | negate-conditional | `if (inv.voided)` | `if (!inv.voided)` | PENDING | — | — |

## Not mutated

| File | Reason |
| --- | --- |
| src/payments/refund.ts | NO COVERAGE — no test in the scoped run imports it |
| src/payments/logger.ts | Equivalent by construction — logging only |
