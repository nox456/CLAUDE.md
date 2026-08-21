# PRD quality gate

Check the draft against every line before showing it to anyone. Fix what you can; convert
what you cannot into an Open Question with an owner and a needed-by date.

## Truthfulness

- [ ] Every number, date, baseline, and owner traces to the user or a source you can name
- [ ] No fabricated research, user quotes, ticket counts, or metric values
- [ ] Unknowns are written `[TBD — @owner]`, not filled with plausible-looking values
- [ ] Where evidence for the problem is missing, the doc says so

## Problem and goals

- [ ] The problem statement contains no solution language
- [ ] The primary metric has a baseline, a target, a window, and a named source
- [ ] A counter-metric is stated
- [ ] Non-goals list the things a reader would otherwise assume are included

## Requirements

- [ ] Every requirement has an ID and a priority
- [ ] Every requirement is singular — no `and` / `or` joining two behaviors
- [ ] No implementation detail (table, library, endpoint, function names) in any requirement
- [ ] Zero instances of *fast, intuitive, robust, seamless, user-friendly, scalable, secure,
      simple, easy, better, properly, gracefully, as needed, etc.*
- [ ] Every requirement traces up to a goal — anything that does not is scope creep, cut it
- [ ] Nothing restates behavior the product already has (verified in step 3)
- [ ] Contradictions with existing behavior are called out as migration work
- [ ] The Must set alone is a coherent, shippable release

## Acceptance criteria

- [ ] Every Must requirement has at least one criterion
- [ ] Every criterion is observable from outside the system, pass/fail, no interpretation
- [ ] Empty state, invalid input, and permission-denied cases are covered
- [ ] Concurrency covered where two actors can touch the same object

## Non-functional

- [ ] Each NFR has a number and a verification method
- [ ] No boilerplate NFRs nobody intends to verify
- [ ] Auth/permission rules stated for every new surface
- [ ] Where user data is involved: classification, retention, and access are addressed

## Operational

- [ ] Rollout has a gate, phases, a rollback path, and the state users are left in
- [ ] Migration or backfill is specified, or explicitly `none`
- [ ] Telemetry exists for every metric in the goals section
- [ ] Dependencies have an owner and a needed-by date
- [ ] Every open question has an owner and a `blocks build?` answer

## Readability

- [ ] A reader outside the team can follow it without the originating conversation
- [ ] Terminology matches the codebase and existing docs exactly
- [ ] Design is linked, not re-described in prose
- [ ] Status, author, date, and changelog are filled in
