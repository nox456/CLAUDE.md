## Development workflow

When I work an issue (Linear or GitHub), use these skills in this order. Skip an optional step when the issue doesn't need it — never skip a required one.

1. **`write-prd`** — _optional._ Only when the issue needs product requirements before any technical design.
2. **`write-implementation-plan`** — _required._ Takes the PRD when there is one, the issue itself when there isn't.
3. **`implementation-loop`** — _required._ Executes the plan phase by phase.
4. **`write-tests`** — _optional._ Skip it when the issue needs no test coverage.
5. **`mutation-testing`** — _optional, but required whenever step 4 ran_ for the same issue.
6. **`code-review`** — _required._ Reviews against the PRD or the implementation plan.
7. **`refactor-review`** — _optional._ Runs after the code review, never before.

This is the full workflow I follow on team work. On personal projects I usually run only part of it, so follow the steps I ask for instead of assuming the whole chain.
