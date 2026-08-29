# Implementation Plan: [Title]

**Status:** Draft · **Author:** @ · **Issue:** [#N or `none`] · **PRD:** [link or `none`] · **Updated:** YYYY-MM-DD

## Context

[Two or three sentences: what is being built and why now. Link the PRD or issue for the
product requirements — do not restate them here.]

**Current behavior:** [what the code does today in the affected surface, with `path:line`
references so the reader can check]

## Technical requirements

| ID | Requirement | Why it matters |
| --- | --- | --- |
| TR-1 | [constraint the implementation must satisfy — transaction boundary, idempotency, backward compatibility, permission rule, index coverage, error contract, budget] | [what breaks without it] |
| TR-2 | | |

## Design decisions

| # | Fork | Chosen | Rejected | Why |
| --- | --- | --- | --- | --- |
| D-1 | [the choice that had to be made] | [option] | [option] | [one line] |

## Contracts

[The interfaces this work introduces or changes: types, validation schemas, endpoint
signatures, event/job payloads, migration DDL. Concrete and minimal — this is what parallel
work depends on, so it lands first.]

```
<path/to/file> — NEW
[the signature, schema, DDL, or payload shape exactly as it will exist]
```

## Scoped changes

[Rename these headings to the real areas of this repo — the modules, packages, or apps that
own the change — and add any the list below misses. Delete buckets with no changes; never
write an "N/A" row. Mark each artifact NEW / MODIFY / DELETE.]

### Database — `<owner>`

| Artifact | Change | What & why |
| --- | --- | --- |
| `path` | NEW | |

### Backend / API — `<owner>`

| Artifact | Change | What & why |
| --- | --- | --- |
| `path` | MODIFY | |

### Shared modules / contracts — `<owner>`

| Artifact | Change | What & why |
| --- | --- | --- |

### Frontend — `<owner>`

| Artifact | Change | What & why |
| --- | --- | --- |

### Jobs / async — `<owner>`

| Artifact | Change | What & why |
| --- | --- | --- |

### Config & infra

| Artifact | Change | What & why |
| --- | --- | --- |

## Build sequence

[Ordered so each step is independently verifiable and leaves the branch deployable.
Contract-bearing steps first.]

1. **[Step name]** — [what changes]. Covers: [artifacts]. Satisfies: [TR-n].
   **Verify:** [command or observable check]
2. **[Step name]** — …
   **Verify:** …

**Parallelizable after step [n]:** [which steps can run concurrently, and who could take them]

## Verification

[Only checks that can run against what exists once the build sequence is done — the repo's
current suites, a command, an observable behavior. Do **not** list tests to be written; test
coverage for this change is planned separately.]

| Level | What it proves | How |
| --- | --- | --- |
| Existing automated checks | [that nothing already covered regressed] | `<command the repo defines>` |
| Manual / QA | | [steps] |
| Telemetry | | [log, metric, or event to watch after deploy] |

## Migration & rollout

- **Migration / backfill:** [what runs, on how much data, reversible? — or `none`]
- **Flag:** [name and default, or `none`] · **Phases:** [...]
- **Rollback:** [what to revert, in what order, and what state users are left in]
- **Compatibility window:** [where old and new must coexist — deployed clients, in-flight
  jobs, cached payloads — or `none`]

## Risks & open questions

| Item | Type | Impact | Owner | Blocks start? |
| --- | --- | --- | --- | --- |
| [statement] | Risk / Dependency / Question | [what it costs] | @ | Yes / No |

## Out of scope

- **New test coverage** — this plan does not specify tests to write. Planned separately with
  the `write-tests` skill, once the implementation lands.
- [Anything else a reader will assume this plan covers and it does not, with where it goes
  instead.]
