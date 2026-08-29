---
name: implementation-loop
description: Execute an existing implementation plan one phase at a time — implement the phase, run the repo's own checks and the phase's verification, hand back a Conventional Commits message to copy, then mark the phase done in the plan file. Requires an implementation plan; refuses to run without one. Use when asked to "implement the plan", "work the plan", "run the implementation loop", "do the next phase", "continue the plan", or when invoked as /implementation-loop. Writes production code only — it runs the repo's existing tests but never writes new ones, which is a separate test skill's job.
---

# Implementation Loop

Turns a written implementation plan into landed code, one phase per iteration, with the plan
file as the source of truth for progress. The plan is not a suggestion to be re-derived: this
skill executes it, keeps it honest when reality disagrees, and never runs ahead of it.

**One iteration = implement one phase → verify → suggest a commit → mark it done.** Then stop
and report.

## Ground rules

- **No plan, no loop.** This skill needs an implementation plan with an ordered, phased build
  sequence. If there is none, stop and offer `write-implementation-plan` — do not invent phases
  from the prompt and start coding.
- **One phase per iteration, and finish it.** Never batch two phases into one diff, and never
  leave a phase half-applied. A phase too large to finish gets **split in the plan first**, not
  abandoned midway.
- **Stay inside the phase.** Refactors, cleanups, and improvements the current phase does not
  name go in the deviation log, not in the diff — even when they are obviously right. The only
  exception is a change without which the phase's verification cannot pass; do it and record it.
- **Write no tests.** The loop lands production code and runs the suites the repo already has.
  New test files, new cases, new fixtures-for-coverage are a separate skill's job, run after the
  plan is implemented — leaving a phase untested is expected here, not a gap to fill.
  <!-- TODO: name the test-authoring skill here once it exists -->
- **You suggest the commit; the user commits.** Never run `git add`, `git commit`, `git push`,
  or create branches unless the user explicitly asks in that turn.
- **Never mark a phase done over red checks.** Done means the phase's own verification passed
  and the repo's checks are green, or the user was told exactly what is failing and why.
- **Only run commands the repo defines.** Check commands are read from the manifest, task
  runner, or CI config — never guessed from the ecosystem.
- **The plan file is the state.** Progress is written there, not only in the conversation, so
  the next session (or the next person) picks up where this one stopped.

## Workflow

- [ ] Step 0 — Locate the plan (hard gate)
- [ ] Step 1 — Take stock: parse phases, find the resume point, discover the checks
- [ ] Loop, per phase: implement → verify → commit message → mark done → report
- [ ] Wrap up when the last phase is done or the loop is blocked

---

### Step 0 — Locate the plan (hard gate)

Use the path the user gave. If they gave none, look for it — plans beside other plans
(`docs/plans/`, `docs/`), `*implementation-plan*.md` or `*IMPLEMENTATION_PLAN*.md` at the repo
root, or a plan linked from the issue the branch is named after. If several match, list them and
ask which. If none exist, **stop here**: say so and offer to write one with
`write-implementation-plan`.

Read the whole plan before touching any code, plus the repo's agent and contributor docs
(`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`) — they constrain how the phase is implemented.

### Step 1 — Take stock

- **Parse the phases.** The plan's build sequence is the phase list, in order. A plan with no
  ordered steps is not executable — say what is missing and offer to fix the plan instead.
- **Find the resume point.** Read the plan's own progress markers, then sanity-check them
  against the code (`git log`, `git status`, the artifacts of the last "done" phase). Trust the
  code over the marker, and say so if they disagree. Announce which phase you are starting and
  why; ask only if it is genuinely ambiguous.
- **Discover the check commands once**, and reuse them for every iteration. Read
  `references/running-checks.md` for where to find them and the gotchas that waste a run. Say
  up front which checks exist — including "this repo defines none", which is a valid answer.
- **Confirm a clean starting point.** Uncommitted unrelated work in the tree makes the phase
  diff unreviewable and the commit message wrong. Report it and let the user decide before
  starting.

---

## The loop

### L1 — Implement the phase

Work from the phase's own rows: the artifacts it names in the plan's scoped changes, the
contracts it must honor, the requirements it satisfies. Before writing a file, read the closest
existing analogue in that area and match its conventions — layering, naming, error handling.
Reuse what the repo has instead of introducing a second way to do the same thing.

Do not write tests, even when the phase's row mentions them or the code obviously wants them:
note it and move on. If an existing test fails because the phase legitimately changed behavior,
updating that test is a repair, not new coverage — do it and log it as a deviation.

Leave nothing that a reviewer will have to ask about: no debug prints or `console.log`, no
commented-out code, no comments restating what the line does, no scaffolding for a later phase.

### L2 — Verify

In this order, stopping to fix what you broke:

1. **The phase's own verification** — the check the plan wrote for this step. It is the
   definition of done for the phase.
2. **The repo's checks** — format, lint, typecheck, and the repo's existing tests, as the repo
   defines them, scoped to the packages the diff touched, run one at a time. A phase with no
   test covering it is normal; do not add one to make the run feel complete.
3. **A hygiene read of the diff** (`git diff`) for leftover debug output, stray TODOs,
   commented-out code, and noise comments.

Fix every failure your diff caused. A failure that predates the phase is **reported, not
silently fixed** — name it and ask before widening the diff. If a check cannot run at all
(missing service, credential, or environment), say which one and why rather than skipping it
quietly.

### L3 — Suggest the commit message

Read `references/conventional-commits.md`, then propose a single commit for the phase as a
copy-pasteable block:

```
<type>(<scope>): <subject>

<body: why this change, in plain prose>

<footers: Closes #N, BREAKING CHANGE, Co-Authored-By>
```

Derive the type and scope from the repo's own history (`git log --oneline -30`) before falling
back to the spec's defaults. Suggest only — do not stage or commit.

### L4 — Mark the phase done

Edit the plan file in place:

- Mark the phase with the plan's existing convention if it has one (a checkbox, a status
  column); otherwise add a `**Status:** Done — YYYY-MM-DD` line under the step. Do not
  restructure the document to fit a new convention.
- **Log every deviation** under that step, one line each: what the plan said, what you did,
  why. This is the record that keeps the plan trustworthy for the phases still ahead.
- Update anything the phase resolved or created — an open question now answered, a new risk, a
  contract that landed differently, the `Updated:` date in the header.
- Leave the phases you have not run untouched.

### Between iterations

Report compactly: the phase just finished, what changed (files, one line each), the check
results, the commit block, deviations, and what phase is next. Then **stop and ask whether to
continue**.

If the user has already said to run the whole plan, keep going without asking — but still print
the per-phase report and commit block for each one, so every phase stays reviewable and
committable on its own.

---

## When the plan and the code disagree

Expect it — the plan was written before the code existed.

- **A path or symbol the phase names is missing or different.** Find the real one, use it,
  correct the plan's row, and note it in the deviation log.
- **The phase is already implemented** (by an earlier phase, or by someone else). Verify it
  actually satisfies the requirement, then mark it done with a note. Do not rewrite working code
  to match the plan's prose.
- **The phase's approach no longer works**, or the verification is impossible as written. If the
  fix is mechanical, make it and record it. If it changes cost, risk, or observable behavior,
  stop and ask with `AskUserQuestion`, with a recommended option — that is a plan decision, not
  an implementation detail.
- **The phase is blocked** (upstream dependency, missing access, unanswered question). Do not
  fake progress: mark the step `Blocked — <reason, owner>` in the plan, report it, and stop the
  loop. Offer the next unblocked phase only if it does not depend on the blocked one.

## Wrap up

When the last phase is done, print a one-screen recap: phases completed, the ordered list of
commit messages suggested, every deviation from the original plan, checks currently green,
and what remains before the branch is mergeable (anything the plan lists under rollout,
migration, or open questions).

State plainly that the change ships without new test coverage and that writing it is the next
step. <!-- TODO: name the test-authoring skill here once it exists -->

Then stop. Writing the tests, opening the PR, writing the QA-readable plan, and running the
closing review are good next steps — offer them, do not do them unasked.
