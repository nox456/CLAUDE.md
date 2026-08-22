---
name: write-implementation-plan
description: Write a technical implementation plan — ground the design in the real repo, then produce a plan with a change list scoped by layer (database, backend, shared packages, frontend, jobs, infra, tests), numbered technical requirements, the contracts other work depends on, an ordered build sequence with verification, and a rollback path. Use when asked to "write an implementation plan", "plan this issue", "plan the implementation", "how should we build this", "write a technical design", or when invoked as /write-implementation-plan.
---

# Write an Implementation Plan

Produces the engineering counterpart to a PRD: a document another developer can execute
without re-deriving the design. A PRD says what the product must do; this says **which code
changes, in which packages, in which order**. The value is in steps 2 and 3 (mapping the
real repo + resolving the forks), not in the template — a template filled from a one-line
prompt is a confident-looking list of files that do not exist.

## Ground rules

- **Ground every reference.** Every path, symbol, table, endpoint, env var, and package
  named in the plan is either verified to exist or explicitly marked `NEW`. A plan pointing
  at a file that is not there costs more than no plan at all.
- **Every change is scoped.** Each row of the change list sits in exactly one bucket, named
  with the package or app that owns it. Nothing lands in "misc", and no bucket is listed
  with nothing in it.
- **Technical requirements, not product requirements.** Transaction boundaries, idempotency,
  backward compatibility, permission checks, index coverage, perf budgets, error contracts.
  If a statement would read identically for *any* implementation of the feature, it belongs
  in the PRD — link it, do not copy it.
- **Steps are ordered by dependency and independently verifiable.** Contract → producer →
  consumer. Every step ends with a way to prove it works, and leaves the branch deployable
  (behind a flag if needed).
- **Reuse before invention.** Look for the existing helper, pattern, or table first. A plan
  that introduces a second way to do something the repo already does must justify it in
  Design decisions.
- **Unknowns stay unknown.** `[TBD — @owner]` or an open question — never a plausible-looking
  guess at a table name, a library, or an API shape.
- **Write no code and open no PRs.** This skill produces one Markdown document.

## Workflow

- [ ] Step 1 — Frame: read the source of truth, size the work
- [ ] Step 2 — Map: derive the real scope buckets and conventions from the repo
- [ ] Step 3 — Decide: resolve the forks that change cost, risk, or behavior
- [ ] Step 4 — Draft: agree the save path, then fill the template in dependency order
- [ ] Step 5 — Self-review: run the quality gate, verify the paths
- [ ] Step 6 — Hand off: report path, scope counts, blocking questions

---

### Step 1 — Frame

Start from what already exists, never from the prompt alone: the ticket and **its comments**
(`gh issue view <n> --comments` where the tracker is GitHub, otherwise ask for it), the PRD if
there is one, design links, related ADRs, prior plans in the repo — their structure is the
house style, match it — and the version-control history for the surface being changed.

Size the work before writing. If it touches one or two files in a single package with no
cross-layer effect, say so and offer a five-line plan instead of the full document. Ceremony
around a one-line fix is a cost, not a deliverable.

### Step 2 — Map the repo

**The scope buckets are not a fixed list — derive them from this repo.** Find how this
codebase is actually partitioned: the build or dependency manifest at the root, whatever it
declares as workspaces / modules / projects, and the top-level source directories. A monorepo
buckets by package and app; a single-package repo buckets by its real modules (`parser`,
`scheduler`, `cli`); a service repo may bucket by layer. Name buckets after directories that
exist here — never after the generic layer names in the template.

For each affected area, read the closest existing analogue — the router next to the one being
added, the last migration, a sibling screen — and capture:

- naming and layering conventions (what calls what, what is not allowed to call what)
- generated artifacts (types, migrations, API clients, locale bundles) and the command that
  regenerates them
- the test layout, plus the build / test / lint commands the repo actually defines — read them
  from the manifest, task runner, or CI config; never assume a package manager or a command name
- anything in the repo's agent or contributor docs (`CLAUDE.md`, `AGENTS.md`,
  `CONTRIBUTING.md`, ADRs) that constrains the change

Read `references/scoping-changes.md` before writing the change list — it holds the per-layer
buckets and the ripple changes plans most often miss (index for the new query path, env var
in every environment, permission check on the new endpoint, cache invalidation, flag cleanup).

In an unfamiliar repo, dispatch an `Explore` agent per surface rather than reading broadly
yourself.

### Step 3 — Decide

Two kinds of fork:

- **Yours.** Mechanical choices — which file, which helper, where the type lives. Decide,
  record the choice, move on. Do not ask.
- **The user's.** Anything that changes cost, risk, or observable behavior: new table vs. new
  column, sync vs. queued, backfill vs. dual-read, extend a package vs. create one, breaking
  API change vs. versioned endpoint, migrate existing rows or leave them. Batch these with
  `AskUserQuestion` — at most 4 per round, at most 2 rounds — and always propose a
  recommended default, because correcting a proposal is faster than filling a blank.

Record every real fork in **Design decisions**: what was chosen, what was rejected, one line
of why. That section is what stops the same debate reopening in code review.

Stop deciding the moment the build sequence is executable; everything still unresolved becomes
an open question with an owner. **Never block the whole document on one unanswered question.**

### Step 4 — Draft

Use `assets/implementation-plan.md`. Fill it in this order, because each section constrains
the next: context → technical requirements → design decisions → contracts → scoped changes →
build sequence → verification → migration/rollout → risks.

Two sections carry the weight:

- **Scoped changes** — one table per bucket, one row per artifact, each row marked
  `NEW` / `MODIFY` / `DELETE` with a one-line what-and-why. Delete buckets with no changes;
  never write a row that says "N/A". This is the section a reviewer reads first to judge
  blast radius.
- **Build sequence** — those rows turned into ordered, individually verifiable steps.
  Contract-bearing steps (migration, shared types, API schema) come before their consumers, so
  work can be parallelized after them.

Keep file lists, verification steps, and test inventories in their **own** sections. The
QA-readable version of this plan is produced by deleting those sections wholesale — cheap if
they are separated, a rewrite if they are woven into the prose.

**Ask the user where to save it** with `AskUserQuestion` before writing the file — never
pick the path silently, and never write outside the path they choose. Fold the question into
the last decision round from step 3 if a round is still available; otherwise ask it on its
own here, once the slug is known.

Propose concrete paths built from what the repo actually has, best candidate first and
labelled as recommended:

1. Beside existing plans, matching their naming exactly, if the repo already has some
2. `docs/plans/<YYYY-MM-DD>-<slug>.md` if a `docs/` directory exists
3. `<slug>-implementation-plan.md` at the repo root

Two or three concrete options is enough — the user can always type a path of their own. If
the answer names a directory that does not exist yet, create it. Where the repo has no
convention of its own and the work has a ticket, put the ticket ID in the proposed filenames
so the plan and the ticket stay findable together.

### Step 5 — Self-review (gate)

Run the grounding pass first: for every non-`NEW` path in the change list, confirm it exists
(`ls`, `rg`). Fix the path, or mark it `NEW`, or drop the row.

Then read `references/review-checklist.md` and check the draft against every line. Fix what
you can; anything you cannot fix without the user becomes an open question with an owner.
Repeat until the checklist passes.

**Do not present a plan that has not been through this pass.**

### Step 6 — Hand off

Report, compactly:

- the file path, and the issue or PRD it implements
- the change count per scope bucket (e.g. `db 2 · api 5 · webui 3 · tests 4`)
- the number of build steps and what step 1 is
- the decisions you made on the user's behalf that they may want to overturn
- the open questions that **block starting**, ranked, each with an owner

Then stop. Splitting the plan into tickets, or starting step 1, are good next steps — offer
them, do not do them unasked.
