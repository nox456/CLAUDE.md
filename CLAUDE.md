## Development workflow

When I work an issue (Linear or GitHub), follow these steps in this order. Skip an optional step when the issue doesn't need it — never skip a required one.

1. **`write-prd`** — _optional._ Only when the issue needs product requirements before any technical design.
2. **`write-implementation-plan`** — _required._ Takes the PRD when there is one, the issue itself when there isn't.
3. **`implementation-loop`** — _required._ Executes the plan phase by phase.
4. **`write-tests`** — _optional._ Skip it when the issue needs no test coverage.
5. **`mutation-testing`** — _optional, but required whenever step 4 ran_ for the same issue.
6. **`code-review`** — _required._ Reviews against the PRD or the implementation plan.
7. **`refactor-review`** — _optional._ Runs after the code review, never before.
8. **Attach docs** — _required._ Not a skill: once the issue is wrapped up, attach the final PRD (when there is one) and implementation plan to the issue. It runs last because both can change during implementation. Ask me before posting.

Through `/work-issue`, which only continues an issue `/start-issue` set up, steps 4–7 run in isolated subagents (`tester`, `mutation-tester`, `code-reviewer`, `refactor-reviewer`) so no verifier grades code it wrote. Steps 2–3, the review fixes and step 8 stay in the main session. Running any of these skills by hand still runs it in-session, as before.

This is the full workflow I follow on team work. On personal projects I usually run only part of it, so follow the steps I ask for instead of assuming the whole chain.
