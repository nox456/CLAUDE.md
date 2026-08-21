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

```ts
// packages/<pkg>/src/<file>.ts — NEW
```

## Scoped changes

[One table per bucket. Delete buckets with no changes; never write an "N/A" row. Mark each
artifact NEW / MODIFY / DELETE.]

### Database — `<package>`

| Artifact | Change | What & why |
| --- | --- | --- |
| `path` | NEW | |

### Backend / API — `<package>`

| Artifact | Change | What & why |
| --- | --- | --- |
| `path` | MODIFY | |

### Shared packages / contracts — `<package>`

| Artifact | Change | What & why |
| --- | --- | --- |

### Frontend — `<app>`

| Artifact | Change | What & why |
| --- | --- | --- |

### Jobs / async — `<package>`

| Artifact | Change | What & why |
| --- | --- | --- |

### Config & infra

| Artifact | Change | What & why |
| --- | --- | --- |

### Tests

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

| Level | What it proves | How |
| --- | --- | --- |
| Unit | | `<command>` |
| Integration | | `<command>` |
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

[What a reader will assume this plan covers and it does not, with where it goes instead.]
