# Writing requirements that survive review

Load this before filling the requirements, acceptance criteria, and NFR sections.

## The seven properties every requirement needs

From ISO/IEC/IEEE 29148, the requirements-engineering standard. Check each statement against
all seven:

| Property | Test to apply |
| --- | --- |
| **Necessary** | Delete it — does anything in the goals section stop being achievable? If not, cut it. |
| **Singular** | Does it contain `and`, `or`, `also`, or a comma list of behaviors? Split it. |
| **Unambiguous** | Could two engineers build different things from this sentence? |
| **Verifiable** | Can QA write a pass/fail test without asking you what you meant? |
| **Complete** | Does it stand alone, without a conversation you had last week? |
| **Consistent** | Does it contradict another requirement, or existing product behavior? |
| **Traceable** | Does it map up to a goal in the goals section and down to acceptance criteria? |

## Statement patterns

**Functional requirement** — one behavior, active voice, `shall`:

```
When <trigger / precondition>, the <system or surface> shall <observable behavior>.
The <system> shall <observable behavior> for <user class>.
```

`shall` = mandatory. `should` = preferred but negotiable. Never use `will`, `may`, `might`,
`could`, or `handle` — none of them tell an engineer whether to build it.

**Acceptance criteria** — Given/When/Then, one observable outcome per line:

```
Given <starting state>, when <action>, then <observable result>.
```

Each criterion must be a fact a tester can observe from outside the system. `then the data
is saved correctly` is not observable; `then the row appears in the list with status
"Pending"` is.

Cover, for every requirement: the happy path, the empty state, an invalid input, a
permission-denied case, and — where two actors can touch the same object — the concurrent
case.

## Bad to good

| Bad | Why it fails | Good |
| --- | --- | --- |
| The dashboard should be fast. | Unverifiable adjective | The dashboard shall render the first row within 2s at p95 for accounts with up to 10k records. |
| Users can manage their team. | Not singular, not observable | FR-1: An admin shall be able to invite a user by email. FR-2: An admin shall be able to revoke a member's access. |
| Handle errors gracefully. | No behavior specified | When the payment provider returns a 5xx, the system shall retain the draft order and show the retry banner. |
| Add a `status` column to `orders`. | Implementation, not requirement | The system shall display each order's fulfilment state to the buyer. |
| Improve onboarding conversion. | That is a goal, not a requirement | Belongs in the goals section. The requirement is the behavior change intended to move it. |
| The system shall be secure. | Unverifiable, infinite scope | Only users with the `billing:read` permission shall be able to open the invoice list; all others receive 403. |
| Support many concurrent users. | No number | The API shall sustain 500 requests/second with error rate under 0.1%. |

## Non-functional categories

Include only what is genuinely at risk for this change — a boilerplate NFR nobody will
verify is worse than an absent one. Each needs a number and a verification method.

- **Performance** — latency at a stated percentile, throughput, payload size, at a stated load
- **Reliability / availability** — uptime target, retry and timeout behavior, degradation mode
- **Security** — authentication, authorization rule, rate limit, audit trail, secret handling
- **Privacy / compliance** — data classification, retention, residency, consent, the regime it falls under
- **Accessibility** — standard and level (e.g. WCAG 2.2 AA), keyboard and screen-reader paths
- **Observability** — the log, metric, or alert that must exist for on-call to debug this
- **Compatibility** — minimum browser/OS/app version, API version support window
- **Localization** — locales at launch, and what an unsupported locale falls back to

## Prioritization

Use MoSCoW in the priority column: **Must** (release is pointless without it) / **Should**
(painful to omit, release still ships) / **Could** (opportunistic) / **Won't** (recorded here
so nobody assumes it).

If everything is a Must, the scope has not been decided yet. Force the split — the Must set
alone should be a coherent, shippable product.
