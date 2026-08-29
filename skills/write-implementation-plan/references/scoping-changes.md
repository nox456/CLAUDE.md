# Scoping the change list

Buckets are named after **real directories in this repo**, not after generic layers. Not every
repo has the layers below: a library, CLI, or single-service repo buckets by its own modules
(`parser`, `runtime`, `transport`). Use these sections as a prompt for the kinds of change to
hunt for, not as a structure to reproduce. Cover the bucket, then check its "often missed" line
before moving on.

## Database / data layer

Schema tables and columns, enums, indexes, constraints, migrations, seeds, views, RLS or
row-level policies, ORM model definitions.

**Often missed:** an index for every new query path and filter; nullability and default for a
new column on a populated table; whether the migration is reversible; a backfill for existing
rows and how long it runs; unique constraints that a concurrent writer can violate; seed and
fixture data used by local dev; read-replica vs. primary routing for the new query.

## Backend / API

Endpoints or procedures, request/response validation schemas, service and domain logic,
authorization checks, repository/query functions, error mapping, rate limits, webhooks.

**Often missed:** the permission check on **every** new endpoint, including the read ones;
transaction boundaries when two writes must land together; idempotency for anything a client
can retry; pagination and a bound on any new list; input validation at the edge rather than
deep in the service; error shape matching the existing contract instead of leaking internals.

## Shared packages / contracts

Types, validation schemas, enums and their labels, generated clients, SDK surface, constants,
utilities used by more than one app.

**Often missed:** every consumer of a changed type — grep, do not guess; the regeneration
command for generated artifacts, named in the step that needs it; version bumps and dependency
ranges; keeping a label/display mapping in one place instead of copying it per consumer.

## Frontend

Routes and screens, components, forms, client state and cache, data fetching hooks, empty and
error states, permissions in the UI, i18n strings, styling.

**Often missed:** loading, empty, error, and permission-denied states for every new view;
cache invalidation after a mutation; optimistic update rollback; i18n entries in every locale
file; accessibility on new interactive elements; behavior on the smallest supported viewport
and on native if the repo ships a native app.

## Jobs / async

Queues, workers, cron and scheduled tasks, event consumers, retries, dead letters.

**Often missed:** what happens when the job runs twice; what happens when it fails halfway;
retry and backoff policy; ordering assumptions between jobs; the naming convention the
scheduler enforces; whether an in-flight job written by the old code can be read by the new.

## Config & infra

Env vars, feature flags, secrets, CI workflows, build config, IaC, dependencies, cron
definitions, dashboards and alerts.

**Often missed:** a new env var added to **every** environment plus the example file and the
deploy config; the flag's default per environment and the ticket to remove it later; a new
dependency's real cost (license, install size, build time); CI steps that must run for the new
module; alerting on the new failure mode.

## Tests — out of scope

Do not create a tests bucket. Unit, integration, e2e, fixtures, mocks, and factories are **not**
planned here: what new coverage the change needs is decided by the test skill after this plan
exists. <!-- TODO: name the test-authoring skill here once it exists -->

What still belongs in this plan: the commands the repo **already** defines, recorded in
Verification so a step can be proved green, and a line under Out of scope pointing at the test
skill. If a schema or contract change breaks existing fixtures, that fixture file is a MODIFY
row in the bucket that owns it — repairing what exists is not authoring coverage.

## Docs

READMEs, contributor docs, API docs, changelog, runbooks for the new operational surface.

---

## Cross-cutting sweep

Before finalizing, walk these once:

1. **Consumers** — grep for every symbol, endpoint, table, and env var being changed. Each hit
   is either in the change list or explicitly unaffected.
2. **Generated code** — anything derived from a changed source, and the command that rebuilds
   it, appears as its own step.
3. **Data already in the old shape** — rows, cached payloads, queued jobs, deployed clients.
   Each gets a migration, a compatibility window, or an explicit "acceptable to break".
4. **Deletions** — code the change makes dead is removed in the plan, or tracked as follow-up.
   Silent orphans are how a codebase rots.
