---
name: write-prd
description: Write a Product Requirements Document — interview the requester, ground the requirements in the real codebase, then produce a PRD with problem, success metrics, scope and non-goals, numbered functional requirements, Given/When/Then acceptance criteria, non-functional requirements, risks and open questions. Use when asked to "write a PRD", "create a product requirements document", "spec this feature", "turn this idea into requirements", "write a product spec", or when invoked as /write-prd.
---

# Create a PRD

Produces a PRD that engineering and QA can build and verify against, without inventing
facts. The value is in steps 2 and 3 (interview + grounding), not in the template — a
template filled from a one-line prompt is a plausible-looking document full of guesses.

## Ground rules

- **Never invent facts.** Every number, date, baseline, owner, and metric target comes from
  the user or a source you can cite. Anything else is written as `[TBD — @owner]`, never as
  a confident-sounding placeholder value.
- **Requirements describe observable behavior, not implementation.** No table names, no
  library choices, no function names. If the "how" is genuinely constrained, it belongs in
  Constraints, not in a requirement.
- **One requirement per statement.** No `and` / `or` joining two behaviors. Each gets an ID
  (`FR-1`, `NFR-1`) so acceptance criteria, tickets, and tests can point back at it.
- **No unverifiable adjectives.** *fast, intuitive, robust, seamless, user-friendly,
  scalable, secure* are banned in requirements — replace each with a threshold and a way to
  measure it.
- **Non-goals are a deliverable**, not filler. Most scope disputes come from what the doc
  never said it excluded.
- **A PRD memorializes discovery; it does not replace it.** If there is no evidence for the
  problem, write `Evidence: none — assumption` and keep going. Do not manufacture user
  research.
- **Write no code and open no PRs.** This skill produces one Markdown document.

## Workflow

- [ ] Step 1 — Frame: pick the format, collect the inputs that already exist
- [ ] Step 2 — Interview: close the gaps that change what gets built
- [ ] Step 3 — Ground: check the claims against the codebase and existing docs
- [ ] Step 4 — Draft: fill the template in dependency order
- [ ] Step 5 — Self-review: run the quality gate and fix what it catches
- [ ] Step 6 — Hand off: report path, metric, and blocking open questions

---

### Step 1 — Frame

Pick the format up front; it sets how much you ask for.

| Use | When |
| --- | --- |
| `assets/prd-one-pager.md` | One feature or enhancement, one team, no new external dependency, no data migration, roughly under two weeks |
| `assets/prd-full.md` | New product or surface, multiple teams, payments / auth / compliance / privacy exposure, a migration or backfill, or a rollout that can hurt users |

Default to the one-pager and grow it — cheaper than trimming a bloated full PRD. If the
request clearly matches the right column, use the full template without asking.

Then gather what already exists before asking the user for anything: the linked issue or
ticket (`gh issue view <n>` where the tracker is GitHub, otherwise ask for it), design links,
prior PRDs in the repo, related ADRs. Read them. Do not re-ask for what a linked ticket
already answers.

### Step 2 — Interview

**Never skip this step**, even when the request looks complete. Ask with `AskUserQuestion`,
batched — at most 4 questions per round, at most 2 rounds. Prioritize the unknowns that
change *what gets built*:

1. **Problem + evidence** — who is hurting, and how do we know? (ticket volume, metric,
   interviews, "gut feel" is an acceptable answer — record it as such)
2. **Success metric** — the one number that moves, its current baseline, the target, and the
   window to hit it
3. **Primary user and trigger** — which role, at what moment in their work
4. **Non-goals** — what someone will reasonably assume is included that is not
5. **Hard constraints** — deadline, compliance regime, platform, a dependency another team
   owns
6. **Rollout expectations** — feature flag, phased percentage, migration or backfill needed

Offer a concrete recommended option in each question rather than an open prompt — it is
faster to correct a proposal than to fill a blank. Stop interviewing the moment you can
write testable acceptance criteria; everything still unknown becomes an Open Question with
an owner. **Never block the whole document on one unanswered question.**

### Step 3 — Ground in reality

For anything touching an existing codebase, before writing a single requirement:

- **Establish current behavior.** It becomes the *Current state* section and it stops you
  from specifying as new something the product already does.
- **Steal the team's vocabulary.** Use the entity, role, status, and flag names that appear
  in the code and existing docs. Vocabulary drift between PRD and codebase is a top cause of
  the wrong thing being built.
- **Flag contradictions.** A requirement that conflicts with existing behavior is a
  migration requirement — say so explicitly, including what happens to data and users
  already in the old state.

For an unfamiliar repo, dispatch an `Explore` agent for the relevant surface rather than
reading broadly yourself.

### Step 4 — Draft

Read `references/writing-requirements.md` before writing the requirements and acceptance
criteria sections — it holds the statement patterns, the NFR categories worth considering,
and the bad-to-good rewrites.

Fill the template **in this order**, because each section constrains the next:
problem → success metrics → scope and non-goals → requirements → acceptance criteria →
NFRs → risks. If you cannot state the metric, you cannot judge whether a requirement
belongs — go back to step 2 instead of writing requirements anyway.

Where to save it, in priority order:
1. Beside existing PRDs, matching their naming, if the repo already has some
2. `docs/prd/<YYYY-MM-DD>-<slug>.md` if a `docs/` directory exists
3. `<slug>-prd.md` at the repo root

Keep prose decisive and short. Link the prototype or design instead of describing it in
paragraphs — where a high-fidelity design exists, it is the spec for look and interaction,
and the PRD covers behavior, rules, and edge cases.

### Step 5 — Self-review (gate)

Read `references/review-checklist.md` and check the draft against every line. Fix what you
can. Anything you cannot fix without the user becomes an entry in Open Questions with an
owner and a needed-by date. Repeat until the checklist passes.

**Do not present a PRD that has not been through this pass.**

### Step 6 — Hand off

Report, compactly:

- the file path and which format you used
- the problem statement in one line, and the success metric with baseline → target
- how many functional requirements, and which sections are still `[TBD]`
- the open questions that **block starting the build**, ranked, each with its owner

Then stop. Splitting the PRD into tickets, or generating test cases from the acceptance
criteria, are good next steps — offer them, do not do them unasked.
