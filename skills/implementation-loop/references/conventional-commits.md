# Commit message for a phase

One phase, one commit. The message is a **suggestion the user copies** — never run `git commit`
yourself unless asked in that turn.

## Match the repo before matching the spec

Run `git log --oneline -30` first. The repo's own history decides:

- which **types** are actually in use (many repos only ever use `feat`, `fix`, `chore`, `docs`)
- the **scope vocabulary** — package names (`api`, `webui`), module names (`parser`), or areas
  (`skills`, `ci`) — reuse an existing scope verbatim rather than inventing a synonym
- whether scopes are used at all, and whether the subject is capitalized
- whether issues are referenced in a footer (`Closes #12`) or in the subject

The spec below is the fallback for a repo with no established style, not an override for one
that has it.

## Format

```
<type>(<scope>)<!>: <subject>

<body>

<footers>
```

- **type** — required, lowercase, from the table below.
- **scope** — optional but preferred: the package, module, or area the phase touched. One scope.
  If the phase genuinely spans several, either drop the scope or split the commit.
- **`!`** — before the colon when the commit breaks a consumer. Requires a `BREAKING CHANGE:`
  footer explaining what breaks and what to do.
- **subject** — imperative mood ("add", not "added"/"adds"), no trailing period, ≤ 72 chars
  including the prefix. Describes the change, not the phase number: `feat(api): add refund
  endpoint`, never `feat: phase 3`.
- **body** — optional, blank line before it, wrapped at ~72. Says **why**, and what the reader
  cannot see in the diff (the decision taken, the constraint honored). Skip it when the subject
  is genuinely the whole story.
- **footers** — `Closes #N` / `Refs #N`, `BREAKING CHANGE: …`, `Co-Authored-By: …` if the repo
  uses it.

## Types

| Type | Use for |
| --- | --- |
| `feat` | New user-facing capability or behavior |
| `fix` | Corrects broken behavior |
| `refactor` | Behavior-preserving restructure |
| `perf` | Behavior-preserving speed or resource win |
| `test` | Tests only |
| `docs` | Documentation, comments, plans only |
| `build` | Build system, dependencies, packaging |
| `ci` | CI configuration and pipelines |
| `chore` | Housekeeping that fits nothing above |
| `revert` | Reverts a previous commit; name it in the body |

Pick by **what the change does to the product**, not by which files moved. A migration plus the
endpoint that needs it is `feat`. A migration that only renames a column behind an unchanged API
is `refactor`.

## Examples

```
feat(api): add idempotent refund endpoint

Refunds are retried by the payment provider, so the handler keys on the
provider's request id and returns the original result on replay instead
of issuing a second refund.

Closes #142
```

```
fix(webui): keep filter state when the invoice list refetches

Closes #217
```

```
refactor(parser)!: return a Result instead of throwing

BREAKING CHANGE: parse() no longer throws on malformed input. Callers
must check result.ok before reading result.value.
```

## Avoid

- `chore: updates` / `fix: bug` / `feat: changes requested` — says nothing.
- A subject naming the plan or phase instead of the change.
- Two unrelated behaviors in one commit because they landed in the same phase; the phase was
  too coarse, so suggest two commits and say which files belong to each.
- A body that narrates the diff file by file. The diff already does that.
