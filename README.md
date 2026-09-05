# CLAUDE.md

Personal Claude Code configuration: global instructions and custom skills.

The real files live here and are symlinked into `~/.claude/`, so editing them in
this repo updates Claude Code immediately — no copy step, nothing to keep in sync.

## Layout

```
CLAUDE.md              ->  ~/.claude/CLAUDE.md
skills/<name>/         ->  ~/.claude/skills/<name>
install.sh                 creates/refreshes the symlinks
```

## Skills

| Name | Description | Depends on |
| --- | --- | --- |
| [write-prd](skills/write-prd/) | Interviews the requester and grounds the result in the codebase to produce a PRD with scope, numbered requirements and Given/When/Then acceptance criteria. | — |
| [write-implementation-plan](skills/write-implementation-plan/) | Turns an issue or PRD into a technical plan: change list by layer, numbered requirements, ordered build sequence, rollback path. | `write-prd` (optional input) |
| [implementation-loop](skills/implementation-loop/) | Executes an implementation plan one phase at a time — implement, verify, suggest a commit, mark the phase done. | `write-implementation-plan` |
| [write-tests](skills/write-tests/) | Audits the existing coverage behavior by behavior, writes the missing unit tests (happy path, edge cases, error path) plus optional flow-based integration tests, and records the result in the plan. | `write-implementation-plan`, `implementation-loop` |
| [mutation-testing](skills/mutation-testing/) | Injects one deliberate defect at a time into the code under test and reports which mutants the suite killed, which survived, and the mutation score. | `write-tests` (optional input) |
| [code-review](skills/code-review/) | Reviews changed code for functional defects against the document it was built from, with severities and a merge-readiness score. | `write-prd` or `write-implementation-plan` |
| [refactor-review](skills/refactor-review/) | Reviews working code for behavior-preserving cleanups — duplication, misplaced helpers, convention drift, dead code — with a refactor score. | `write-implementation-plan`, `code-review` |
| [pr-review](skills/pr-review/) | Publishes a code review to a GitHub pull request — inline comments on the findings you pick plus one summary comment carrying the finding list and the merge-readiness score. | `code-review` |
| [english-coach](skills/english-coach/) | Appends a short English-coaching note to every response, rewriting the phrasings that read non-native. | — |

## Setup on a new machine

```bash
git clone <this-repo> ~/Documents/Projects/CLAUDE.md
cd ~/Documents/Projects/CLAUDE.md
./install.sh
```

`install.sh` is idempotent. It backs up any real file it would replace to
`<name>.bak.<timestamp>`, and removes stale symlinks left behind by skills that
were deleted from the repo.

Set `CLAUDE_CONFIG_DIR` to link somewhere other than `~/.claude`.

## Adding a skill

Create `skills/<name>/SKILL.md` here, add a row to the Skills table above, then run
`./install.sh` to link it. The `/write-skill` skill walks the whole process.
