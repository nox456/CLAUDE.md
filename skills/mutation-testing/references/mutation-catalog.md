# Mutation catalog

Read at Step 3, before planning a single edit. A mutant is worth running only if a competent
test *should* catch it. Everything here exists to keep the budget on those.

## The rule for choosing

For each candidate line ask: **if a developer made this exact mistake, would it reach
production?** If the answer is "the type checker would stop it" or "no output changes", the
mutant is wasted budget. Plan the ones where the answer is "yes, and it would be quiet."

Prefer, in this order:

1. Lines carrying a numbered requirement or a documented business rule.
2. Boundaries and guards on money, permissions, deletion, and retries.
3. Branches that the tests reach but may not distinguish (both sides return a similar shape).
4. Everything else.

One mutant per line. Two mutants on the same expression tell you almost the same thing.

## Operators

| Operator | Edit | Plan it when |
| --- | --- | --- |
| `conditional-boundary` | `>` ↔ `>=`, `<` ↔ `<=` | Any comparison against a limit, count, threshold, price, or date. The highest-yield operator there is |
| `negate-conditional` | `==` ↔ `!=`, `if (x)` → `if (!x)` | Any branch whose two sides have different observable outcomes |
| `remove-conditional` | `if (cond)` → `if (true)` / `if (false)` | Guards: permission checks, feature flags, validation, soft-delete and status filters |
| `arithmetic` | `+`↔`-`, `*`↔`/`, `%`→`*` | Money, quantities, percentages, offsets, pagination, FX |
| `call-removal` | Delete a statement whose value is unused | Writes, emits, logs-that-matter, cache invalidations, audit records — the effects tests forget to read back |
| `return-value` | `return x` → `return null` / `[]` / `0` / `""` / `!x` | Any function whose result the caller branches on |
| `literal` | `3` → `0`/`1`, `"active"` → `""`, `true` ↔ `false` | Magic numbers, status strings, enum members, default arguments |
| `collection` | Drop `.filter(…)`, drop `.sort(…)`, `.slice(0,n)` → full list | Filters and ordering that the tests may only length-check |
| `exception` | Replace `throw new X(…)` with a normal return, or empty a `catch` that does real work | Error paths the plan names, and rollback/compensation logic |
| `await-removal` | Drop `await` before a call whose result is unused | Fire-and-forget bugs: the write races the assertion and the test still passes |
| `boundary-off-by-one` | `i < n` → `i <= n`, `slice(0, n)` → `slice(0, n-1)` | Pagination, batching, chunking, retry counters |

## Aim by layer

| Layer | Mutate first |
| --- | --- |
| Pure logic / calculators | Every comparison boundary and every arithmetic operator |
| API handlers | The auth/permission guard, the validation branch, the status code literal |
| Repository / queries | The `WHERE` predicate, the soft-delete filter, the `ORDER BY`, the `LIMIT` |
| Jobs / async | The retry limit, the idempotency guard, the `await` on the state write, the rollback in the failure branch |
| Frontend | The condition behind a disabled/hidden affordance, the empty-state branch, the permission gate |
| Validation schemas | Required → optional, the min/max bound, the enum's member list |

## Never plan these — equivalent by construction

They cannot change observable behavior, so they always survive and always mean nothing:

- Anything inside a logging, tracing, metrics or `console.*` call.
- Comments, formatting, and type-only positions (annotations, generics, `as` casts).
- A `catch` block that only re-throws.
- Reordering independent, side-effect-free statements.
- A change the type checker rejects — it is INVALID, not a mutant. Prefer type-preserving edits
  (`>` → `>=`, not `"active"` → `1`).
- Initialising a variable that is unconditionally assigned before its first read.
- A default that is always overridden by every caller in the codebase.
- Dead code you already know is unreachable — report it as dead code instead.

## Writing the mutation down

Each ledger row must be applyable by someone who has not read the file: the exact `path:line`,
the operator name from the table above, and the before/after as source. If the edit cannot be
written as a one-line before/after, it is too big — split it or drop it.
