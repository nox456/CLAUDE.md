# Running the repo's checks

Read this once per session, in step 1, and reuse the commands you find for every phase.

## Discover, never guess

Look, in this order, and stop when you have a real command list:

1. **The repo's agent/contributor docs** — `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` often
   state the exact commands and their order.
2. **The build/dependency manifest** — the scripts or task section (`package.json` scripts,
   `Makefile` targets, `pyproject.toml`/`tox.ini`, `Cargo.toml`, `mix.exs`, `composer.json`,
   `justfile`, `Taskfile.yml`, `nx.json`, `turbo.json`).
3. **CI configuration** — `.github/workflows/*.yml`, composite actions such as
   `.github/actions/*/action.y*ml`, `.gitlab-ci.yml`, `Jenkinsfile`. CI is the authoritative
   answer to "what must be green", and it names the commands verbatim.
4. **Pre-commit hooks** — `.pre-commit-config.yaml`, `.husky/`, `lefthook.yml`.

If none of these define checks, the repo has none. Say so and rely on the phase's own
verification — do not invent `npm test` because the repo has a `package.json`.

Detect the package manager from the lockfile (`pnpm-lock.yaml`, `yarn.lock`,
`package-lock.json`, `bun.lockb`, `uv.lock`, `poetry.lock`), never from habit.

## Order and scope

Run **format → lint → typecheck → tests**, one command at a time, never in parallel: the cheap
checks fail fastest, and a formatter that rewrites files invalidates a lint run started
alongside it.

In a monorepo, scope to the packages the phase's diff actually touched (derive them from
`git status` / `git diff --name-only`) and finish one package before starting the next. Do not
run the whole workspace for a one-package phase unless the repo only offers a root command.

Prefer check-only variants for the report (`format:check`, `lint`) and fix variants
(`format:fix`, `lint --fix`) only on files the phase touched.

## Gotchas

- **Watch mode hangs the run.** Test and build commands often default to watch in local dev —
  use the repo's CI flag (`--run`, `--watch=false`, `CI=1`) so the command exits.
- **The tool may not be on the non-interactive PATH.** If a command is "not found" but the repo
  clearly defines it, retry through a login+interactive shell (`bash -lic '…'`) before
  concluding it is missing.
- **Type-aware linters can OOM** at the default Node heap on large packages. An out-of-memory
  abort is not a lint violation — retry with a larger heap
  (`NODE_OPTIONS=--max-old-space-size=8192`) before reporting it.
- **Formatters rewrite files.** After a fix run, say which files were rewritten; they belong in
  the phase's commit.
- **Some tests need a service** (database, queue, container). If it is not running, report the
  specific check as not-run with the reason — never report it as passing, and never report it as
  a failure of the phase.
- **Long test suites**: run the phase's own targeted tests first for the fast signal, then the
  package suite.

## Reporting results

Give a compact table — one row per check, ✅ / ❌ / ⚠️ not-run — and for each failure the
`file:line` plus the one line of output that matters.

Separate the two kinds of red:

- **Caused by this phase** → fix it inside the phase, then re-run that check.
- **Pre-existing** (reproduces on the base commit) → report it, name it as pre-existing, and ask
  before touching it. Widening the phase's diff to fix unrelated breakage makes the commit
  unreviewable.

A check that stays red blocks marking the phase done. State that plainly instead of
qualifying it away.
