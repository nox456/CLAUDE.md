---
name: fix-review-findings
description: Fix the findings a `code-review` or `refactor-review` run reported, one finding at a time — the user picks which ones, each fix is verified with the repo's own checks, a Conventional Commits title is suggested for it, and the next finding does not start until the user has committed the previous one. Never commits or pushes. Use when asked to "fix the findings", "fix the review findings", "apply the code review", "apply the refactor review", "fix these issues one by one", "work through the review", "fix finding 3", or when invoked as /fix-review-findings — including right after a review ran in the conversation and the user just says "fix them". Does not answer review comments on a GitHub PR — that is `fix-pr-review`'s ground — and does not write new tests, which is `write-tests`' job.
---

# Fix Review Findings

Turns the findings of a `code-review` or `refactor-review` run into one commit per finding.
The failure it exists to prevent: a single sprawling "address review" diff where nobody can
tell which change fixed which finding, or which one quietly broke something.

**One iteration = one finding → fix → verify → commit title → wait until it is committed.**

## Ground rules

- **No findings, no run.** The findings come from a review in this conversation or pasted by
  the user. If there are none, stop and offer `/code-review` or `/refactor-review` — never
  invent findings from the diff yourself.
- **The user picks; you fix nothing unselected.** Not even the "obvious" LOW next to the line
  you are editing.
- **One finding per iteration, and only that finding.** Apply what its Suggestion says, at its
  Location. The same pattern elsewhere, nearby cleanups, a better idea — none of it goes in the
  diff unless the finding names it.
- **Refactor findings preserve behavior.** A `refactor-review` fix that changes outputs, side
  effects, errors, or ordering is a bug you introduced. The existing tests must stay green.
- **Write no tests.** A finding whose Suggestion is "add a test covering …" is handed to
  `write-tests`, not fixed here — unless the user explicitly asks in that turn.
- **You suggest the commit; the user commits.** Never run `git add`, `git commit`, `git push`,
  `git stash`, `git restore`, or `git reset`.
- **The commit is the gate.** Do not start the next finding until the previous fix is verifiably
  committed (step 4). "Next" from the user is not proof — `git` is.
- **Only run checks the repo defines.** Read them from `CLAUDE.md`/`AGENTS.md`, the manifest's
  scripts, or CI config. Never guess `npm test` from the ecosystem.

## Workflow

- [ ] Step 1 — Collect the findings and give each a unique ref
- [ ] Step 2 — Get the selection
- [ ] Step 3 — Check the starting point and discover the checks
- [ ] Step 4 — Loop: fix → verify → title → commit gate
- [ ] Step 5 — Wrap up

---

### Step 1 — Collect the findings and give each a unique ref

Parse every finding from the review output. The two formats:

```
code-review (5 lines)          refactor-review (6 lines)
1. <title>                     1. <title>
Severity: BLOCKING|HIGH|...    Severity: HIGH|MEDIUM|LOW
Location: <path:line>          Location: <path:line>
Description: <cause>           Description: <shape and cost>
Suggestion: <fix>              Suggestion: <one-line move>
                               Improving: <label>
```

Both reviews number from 1, so prefix the ref by source: `CR-1`, `CR-2` for code-review,
`RR-1`, `RR-2` for refactor-review. Use these refs everywhere from here on.

If a PRD or implementation plan sits in the repo, read the sections the findings cite; it is
context for the fix, not a gate.

### Step 2 — Get the selection

Show the findings as one table — ref, severity, title, location — ordered: every `CR-` before
any `RR-` (bugs before shape; refactoring buggy code just relocates the bug), then severity
descending. Ask which to fix and recommend every BLOCKING and HIGH, saying so.

`AskUserQuestion` takes at most 4 options per question. With more than 4 findings, list them
in the table and ask the user to reply with the refs (`CR-1, CR-3, RR-2`), or offer grouped
options ("all BLOCKING + HIGH", "all code-review", "let me list refs").

Restate the final ordered list before touching code.

### Step 3 — Check the starting point and discover the checks

```bash
git status --short
git rev-parse --abbrev-ref HEAD
```

Unrelated uncommitted changes would end up in the first fix's commit. Report them and let the
user commit or set them aside — do not do it for them. On the default branch, say so once; the
user decides whether that is fine.

Then find the repo's check commands once (format, lint, typecheck, existing tests) and say
which exist — "this repo defines none" is a valid answer. Reuse them for every finding.

### Step 4 — Loop: fix → verify → title → commit gate

Per selected finding, in the order from step 2:

1. **Record the base**: `git rev-parse HEAD`. The commit gate checks against it.
2. **Re-confirm the finding.** Open the file and read the code at its Location *now* — earlier
   fixes shift line numbers and can make a finding moot. If it no longer holds, say why, mark it
   `STALE`, and move on with no commit.
3. **Fix it.** Exactly what the Suggestion asks, matching the surrounding code's conventions. If
   the fix needs something the finding never asked for — a contract or API change, a migration,
   a behavior change in another file — stop and ask; that is a design decision, not a fix. If it
   cannot be fixed, say so and mark it `BLOCKED` with the reason.
4. **Verify**, in order: the repo's checks scoped to the files the fix touched, one at a time;
   then a read of `git diff` for debug output, commented-out code, and edits outside the
   finding. Fix what your diff broke. A failure that predates the fix is reported, not fixed.
5. **Suggest the title**, one line, copy-pasteable:

   ```
   <type>(<scope>): <what changed, imperative, no period>
   ```

   | Finding | Type |
   | --- | --- |
   | `CR-*` | `fix` |
   | `RR-*` with `Improving: Performance` | `perf` |
   | Any other `RR-*` | `refactor` |

   Take the scope vocabulary and casing from `git log --oneline -30`. Keep it ≤72 characters
   and describe the change, never the finding (`fix(api): stop retry from re-charging on
   timeout`, not `fix: CR-1`). Then list the files to stage, so the commit holds only this fix.
6. **Commit gate.** Stop and wait. When the user says to continue, verify before moving on:

   ```bash
   git log --oneline <base>..HEAD     # must show the new commit
   git status --short                 # the fix's files must not appear
   ```

   No new commit, or the fix's files still dirty, means it is not committed: say exactly what
   is missing and wait again. Do not start the next finding on top of an uncommitted fix. If
   the user wants to drop the fix instead, they discard it themselves; then mark it `DROPPED`.

### Step 5 — Wrap up

When the list is done, report one line per selected finding:

```
CR-1  FIXED    fix(api): stop retry from re-charging on timeout   (a1b2c3d)
CR-3  STALE    already handled by the CR-1 fix
RR-2  BLOCKED  extraction target would create a package cycle
```

Then name what was not selected, and state that nothing was pushed. Offer a re-run of
`code-review` or `refactor-review` over the fixed code, and `write-tests` for any test
suggestions handed off — do none of them unasked.

## Gotchas

- **Locations go stale inside the run.** A finding's `path:line` was right at review time;
  every fix before it moves lines. Always find the code by its content, not by the number.
- **Two findings can share one fix.** When fixing `CR-1` also resolves `CR-3`, do not fold it in
  silently — finish `CR-1`, then report `CR-3` as `STALE` with the commit that resolved it.
- **A `Multiple locations:` finding has no line numbers.** `rg` the symbol from the Description
  to find every site before editing; a fix applied to one copy of a duplication is no fix.
- **Hooks can reject the user's commit.** If `git log` shows no new commit after the user says
  they committed, a pre-commit hook may have failed or rewritten files — ask for its output
  rather than assuming they forgot.
- **`refactor-review` sometimes suggests extracting a util.** Check the import direction first:
  a util the consumer cannot import, or one that creates a cycle, means `BLOCKED`, not a
  creative workaround.
