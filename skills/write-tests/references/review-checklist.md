# Review checklist

Run at Step 5, over every file written, before showing anything. The suite is not executed in
this skill, so this pass is the only verification the tests get. An unchecked box is a fix, not
a caveat.

## Static verification — it will at least load

- [ ] Every import path resolves to a file that exists (`ls` it — do not trust recall).
- [ ] Every imported symbol is exported from that file, spelled exactly that way.
- [ ] Every call under test matches the real signature: arity, argument order, sync vs. async,
      and what it returns. Read the source; do not infer it from the call site you wrote.
- [ ] Every fixture, factory and helper used exists, and is imported from where the sibling
      tests import it.
- [ ] The file is inside the runner's `include` glob for its package, with the naming the
      sibling tests use.
- [ ] Every promise-returning assertion is awaited or returned.
- [ ] Nothing in the file reaches the network, the real clock, or the filesystem outside the
      repo's own test helpers.

## The tests test something

- [ ] Every case asserts an observable outcome on a value the test constructed — not
      `toBeDefined`, not a mock's return value handed straight back.
- [ ] For each case: if the behavior regressed, an assertion breaks. Check the ones covering
      HIGH gaps by mentally reverting the code.
- [ ] No case's only assertion is a mock call count.
- [ ] One behavior per case; no conditionals or loops around assertions outside the repo's own
      table-driven idiom.
- [ ] Case names state the behavior and its outcome, in the register the sibling tests use.
- [ ] No new snapshot is standing in for a numbered requirement.

## Structure and coverage

- [ ] Every group carries all three categories, or states in one line why a category is empty.
- [ ] Every gap the audit ranked HIGH now has a test, or is listed as deliberately left open
      with a reason.
- [ ] No test duplicates a behavior the audit marked Covered.
- [ ] Nothing tests a behavior the plan lists under Out of scope, or an approach its Design
      decisions rejected.
- [ ] Integration tests (if written) go through real entry points, mock only the boundaries the
      repo already mocks, and cover one mid-flow failure.

## Boundaries respected

- [ ] No production file was modified. `git status` shows only test files (and the plan).
- [ ] No existing test was deleted, skipped, or weakened.
- [ ] Any test asserting behavior the code does not currently have is marked with the repo's
      skip/todo idiom and reported as an expected failure with the bug behind it.
- [ ] The plan's "Test coverage" section reports coverage before and after, with the arithmetic
      shown, and nothing else in the plan was restructured.
- [ ] The handoff says plainly that the suite was not run, and gives the command to run it.
