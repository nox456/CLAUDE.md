# Scoping the test command

Read at Step 2, before the baseline run. The command derived here is executed once per mutant,
so every second it wastes is multiplied by the mutant count — and every test it wrongly excludes
turns a killed mutant into a false survivor.

## Find the command the repo already uses

```bash
cat package.json pyproject.toml go.mod Cargo.toml Gemfile 2>/dev/null
rg -n '"(test|test:unit|test:ci)"' package.json
ls vitest.config.* jest.config.* pytest.ini conftest.py 2>/dev/null
```

In a monorepo, do this **in the package that owns the mutated file**, and run the command from
that directory. The root manifest usually delegates; its runner has neither the package's setup
file nor its path aliases, and a scoped run from the root can silently match zero tests.

## Scope it to the surface

Give the runner the test paths, not the source paths, unless the runner supports related-file
selection:

| Runner | Scope by path | Scope by name | Related to a source file |
| --- | --- | --- | --- |
| Vitest | `vitest run src/payments` | `-t "<substring>"` | `vitest related src/payments/charge.ts --run` |
| Jest | `jest src/payments` | `-t "<substring>"` | `jest --findRelatedTests src/payments/charge.ts` |
| pytest | `pytest tests/payments` | `-k "<expr>"` | — (use the path) |
| Go | `go test ./internal/payments/...` | `-run '<regex>'` | — (package granularity) |
| PHPUnit | `phpunit tests/Payments` | `--filter '<regex>'` | — |

`vitest related` and `jest --findRelatedTests` are the best default when they exist: they resolve
the import graph, so a test in another directory that imports the mutated file is still included.

**Verify the scope before trusting it.** Run it once and compare its reported test count with the
full suite's. A scoped run that reports far fewer tests than the files it should cover is
matching on the wrong thing — fix it now, not after twenty false survivors.

## Flags that must never be used

| Never | Why |
| --- | --- |
| `--watch`, `-w`, `--watchAll`, `pytest -f` | The process never exits; the loop hangs forever |
| `-u`, `--update-snapshots`, `--snapshot-update` | The mutant rewrites the snapshot and survives |
| `--bail`, `-x`, `--maxfail=1` | Stops at the first failure, so the killing test is not always the one reported — and the test count becomes useless as an INVALID signal |
| `-o`, `--only-changed`, `--changed` | The set of tests changes between mutants; results are not comparable |
| `--silent` with no reporter | You cannot name the killing test, and an unnamed kill is not a confirmed kill |

## Flags worth adding

- A deterministic reporter that prints test names — `--reporter=verbose` (Vitest),
  `--verbose` (Jest), `-v` (pytest). The report requires the killing test's name.
- Serial execution when the suite shares a database, a temp directory or a port:
  `--no-file-parallelism` / `--poolOptions.threads.singleThread` (Vitest), `--runInBand` (Jest),
  `-p 1` (pytest-xdist off), `-p 1` (Go).
- A seed pin where the runner randomises order (`pytest -p no:randomly`, `--random.seed`).

## Setting the timeout

Run the scoped command once, clean, and take its wall-clock time as the baseline. Use **3× that,
floored at 30 seconds**, as the per-mutant `timeout`. A mutant that turns a bounded loop into an
unbounded one is the reason this matters: without a timeout it hangs the whole run, and with one
it is correctly recorded as a kill.

## When no test covers a file

If the scoped command runs no test that imports a file in the surface, record the file as **NO
COVERAGE** and plan no mutants for it. Every mutant would survive for the same uninformative
reason. Report it in the "Not covered" line so the user can send it to `/write-tests`.
