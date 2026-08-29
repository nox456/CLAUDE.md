# Deriving the repo's test conventions

Read at Step 3, before creating the first test file. Everything here is discovery: this skill
ships no opinion about frameworks, only about matching what is already here. A test written in
the house style gets reviewed; one written in a style of its own gets rewritten.

## Discover, in this order

```bash
cat package.json pyproject.toml go.mod Cargo.toml Gemfile 2>/dev/null   # runner + scripts
ls vitest.config.* jest.config.* playwright.config.* pytest.ini conftest.py 2>/dev/null
rg -n '"(test|test:unit|test:watch|test:e2e)"' package.json             # the real command
```

**In a monorepo, do this per package.** The root manifest usually delegates; the package next to
the change owns the runner, the setup file, the environment and the path aliases. Read the
config that applies to the file you are about to create, not the root one.

Then open **two or three existing test files nearest the code under test** — same package, same
layer, doing the same job. They are the specification for everything below.

## What to extract from them

| Convention | Look for |
| --- | --- |
| File location and name | Beside the source (`charge.test.ts`) vs. a mirrored `tests/` tree vs. `__tests__/`. Match exactly, including the `.test.` / `.spec.` / `_test` choice. |
| Grouping idiom | `describe`/`it`, `test`, table-driven cases, classes. Mirror the three categories in whatever it is. |
| Naming of cases | Sentence-style ("returns an empty array when …") vs. `should_…`. Copy the register, including the language they are written in. |
| Setup and teardown | Which fixtures/factories/builders exist — **use them, never hand-roll a duplicate object literal.** Where the DB is reset, where the seed lives. |
| Mocking boundary | What the repo already stubs (HTTP clients, the clock, the mailer, the queue) and with what (`vi.mock`, `jest.mock`, DI, MSW, a fake adapter). Adopt it; do not introduce a second mechanism. |
| Async idiom | `await` vs. done-callbacks, fake timers, how they wait for effects to settle. |
| Assertion style | The matcher vocabulary in use, custom matchers, and how errors are asserted (`rejects.toThrow`, `assertRaises`, error codes). |
| Integration-test home | Whether flow tests live in a separate directory, project, or config — they usually do, and putting one in the unit project makes it run in the wrong environment. |

## Rules that survive any stack

- **Import from the public entry point** the rest of the code uses, not a deep internal path
  unless the sibling tests do.
- **Reuse the existing factory.** If a factory needs a new field for your case, extend the
  factory; a parallel literal drifts from it within a release.
- **One behavior per case.** Two unrelated assertions in one case means the second is never
  reached once the first fails.
- **No conditionals, loops, or try/catch around assertions** — except the table-driven idiom the
  repo already uses. A test with a branch has an untested branch.
- **Explicit over DRY.** Repetitive, obvious setup inside a case beats a clever helper that hides
  what the case is testing. Extract only what already exists as a fixture.
- **No network, no real clock, no shared mutable state between cases.** Any of the three makes
  the suite order-dependent, and the failure lands on whoever runs it next.

## Traps

- A test placed correctly but outside the runner's `include` glob never runs and never fails.
  Check the glob in the config, not just the directory.
- The wrong test environment (`node` vs `jsdom`) fails at import time with an error that names
  neither — check the config's `environment` before debugging the test.
- Path aliases (`@/…`) resolve through the runner's own config, not only tsconfig. If the sibling
  tests use relative imports, so should yours.
- A setup file registering global mocks means your explicit mock may be overridden, or already
  unnecessary. Read it before adding one.
- Async assertions that are never awaited pass unconditionally. Every promise-returning
  assertion is returned or awaited.
