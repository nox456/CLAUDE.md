# Implementation plan quality gate

Check the draft against every line before showing it to anyone. Fix what you can; convert what
you cannot into an open question with an owner.

## Grounding

- [ ] Every non-`NEW` path in the change list was confirmed to exist
- [ ] Every symbol, table, endpoint, and env var referenced is real or marked `NEW`
- [ ] Naming matches the repo's conventions, not generic ones
- [ ] Current behavior is described from the code, not assumed
- [ ] Nothing conflicts with the repo's agent or contributor docs (`CLAUDE.md`, `AGENTS.md`,
      `CONTRIBUTING.md`, ADRs)
- [ ] No invented library, service, or internal API

## Scoping

- [ ] Buckets are named after real modules, packages, or directories in this repo
- [ ] Every change sits in exactly one bucket — no "misc", no duplicated rows
- [ ] No empty bucket and no "N/A" row survives
- [ ] Every row is marked `NEW` / `MODIFY` / `DELETE` and says why in one line
- [ ] The cross-cutting sweep in `scoping-changes.md` was run: consumers, generated code,
      existing data, deletions
- [ ] Out of scope names what a reader would otherwise assume is included

## Technical requirements

- [ ] Each has an ID and is testable — no *fast, robust, clean, properly, as needed*
- [ ] Each is genuinely technical; product behavior is linked to the PRD, not restated
- [ ] Auth/permission stated for every new surface
- [ ] Transaction, idempotency, and concurrency behavior stated where two writers can collide
- [ ] Backward compatibility stated wherever an existing contract changes
- [ ] Every TR is covered by at least one build step

## Design decisions

- [ ] Every fork that could reasonably have gone the other way is recorded
- [ ] Each has the rejected option and a one-line why
- [ ] Reuse was checked — any new pattern duplicating an existing one is justified here
- [ ] Decisions made on the user's behalf are flagged for the hand-off

## Build sequence

- [ ] Ordered by dependency; contracts and migrations precede their consumers
- [ ] Each step is independently verifiable and leaves the branch deployable
- [ ] Each step names the artifacts it covers
- [ ] Regeneration of generated artifacts is its own step, with the command
- [ ] Steps that can run in parallel are marked

## Verification & operations

- [ ] Every level has a concrete observable check, or a command the repo actually defines —
      never a guessed command, never "run the tests"
- [ ] The failure paths, not only the happy path, are covered
- [ ] Migration/backfill is specified with data volume and reversibility, or explicitly `none`
- [ ] Rollback says what to revert, in what order, and what state users are left in
- [ ] Flag name and default per environment are stated, or explicitly `none`
- [ ] Post-deploy signal to watch is named

## Readability

- [ ] An engineer who was not in the conversation can execute it without asking
- [ ] File lists, verification, and test inventory are in their own sections, so the QA
      version is a deletion and not a rewrite
- [ ] No copied PRD prose; the PRD is linked
- [ ] Status, author, issue/PRD link, and date are filled in
