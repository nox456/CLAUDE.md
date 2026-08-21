# PRD: [Feature name]

| | |
| --- | --- |
| **Status** | Draft / In review / Approved / Shipped |
| **Author** | @ |
| **Reviewers** | @eng-lead, @design, @qa |
| **Target release** | [version or date, or `[TBD]`] |
| **Last updated** | YYYY-MM-DD |

## 1. Problem

[Two or three sentences: who is affected, what they cannot do today, and the cost of leaving
it broken. No solution language.]

**Evidence:** [ticket volume, metric, support themes, interview count — or
`none — assumption`]

**Why now:** [what changed to make this the next thing, rather than later]

## 2. Goals and success metrics

| Metric | Baseline | Target | Window | Source |
| --- | --- | --- | --- | --- |
| [primary metric] | [today's value] | [target] | [e.g. 60 days post-launch] | [dashboard/query] |

**Counter-metric (must not regress):** [the thing this change could plausibly break]

**Non-goals:**
- [Adjacent thing a reader will assume is included, and is not]
- [Deliberately deferred scope, with a pointer to where it is tracked]

## 3. Users and use cases

**Primary user:** [role, and the moment they hit this]

- As a [role], I want to [action] so that [outcome].
- As a [role], I want to [action] so that [outcome].

## 4. Current state

[How this works today, in the team's own vocabulary — entity, status, and flag names as they
exist in the product. Omit for a greenfield surface.]

## 5. Scope

**In scope:** [surfaces, platforms, user segments, locales]

**Out of scope:** [surfaces and segments explicitly untouched this release]

## 6. Functional requirements

| ID | Requirement | Priority |
| --- | --- | --- |
| FR-1 | When [trigger], the system shall [observable behavior]. | Must |
| FR-2 | The system shall [observable behavior]. | Must |
| FR-3 | [...] | Should |

[One behavior per row. Priorities: Must / Should / Could / Won't-this-release.]

## 7. Acceptance criteria

**FR-1**
- Given [starting state], when [action], then [observable result].
- Given [error or edge state], when [action], then [observable result].

**FR-2**
- Given [...], when [...], then [...].

[Cover the happy path plus empty, error, permission-denied, and concurrency states.]

## 8. Non-functional requirements

| ID | Category | Requirement | Verified by |
| --- | --- | --- | --- |
| NFR-1 | Performance | [action] completes in under [N ms] at p95 under [load] | [load test / dashboard] |
| NFR-2 | Security | [control, referencing the existing policy it inherits] | [review / test] |
| NFR-3 | Accessibility | [standard and level, e.g. WCAG 2.2 AA for the new surface] | [audit] |

[Only the categories genuinely at risk here. See `references/writing-requirements.md`.]

## 9. Design and UX

- Prototype: [link]
- Copy: [link, or inline for short strings]
- Known design decisions the build must respect: [...]

## 10. Analytics and telemetry

| Event | Trigger | Properties | Feeds which metric |
| --- | --- | --- | --- |
| `[event_name]` | [when it fires] | [props] | [metric from §2] |

## 11. Dependencies and constraints

| Item | Owner | Needed by | Status |
| --- | --- | --- | --- |
| [API, team, vendor, legal review] | @ | YYYY-MM-DD | [not started / in progress / done] |

## 12. Risks and assumptions

| Risk / assumption | Type | Impact | Mitigation or validation |
| --- | --- | --- | --- |
| [statement] | Value / Usability / Feasibility / Viability | H/M/L | [how it gets tested or reduced] |

## 13. Rollout

- **Gate:** [feature flag name, or `none`]
- **Phases:** [internal → % → GA, with the criterion to advance each step]
- **Migration / backfill:** [what happens to existing data and users, or `none`]
- **Rollback:** [how it gets turned off, and what state users are left in]
- **Support:** [what changes for support/ops, docs needed]

## 14. Open questions

| # | Question | Owner | Needed by | Blocks build? |
| --- | --- | --- | --- | --- |
| 1 | [question] | @ | YYYY-MM-DD | Yes / No |

## 15. Changelog

| Date | Change | By |
| --- | --- | --- |
| YYYY-MM-DD | Initial draft | @ |
