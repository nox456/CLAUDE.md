# CLAUDE.md

Personal Claude Code configuration: global instructions, custom skills, and the subagents and
hooks that run the workflow's verification steps in isolation.

The real files live here and are symlinked into `~/.claude/`, so editing them in
this repo updates Claude Code immediately — no copy step, nothing to keep in sync.

## Layout

```
CLAUDE.md              ->  ~/.claude/CLAUDE.md
skills/<name>/         ->  ~/.claude/skills/<name>
agents/<name>.md       ->  ~/.claude/agents/<name>.md
hooks/<name>           ->  ~/.claude/hooks/<name>
install.sh                 creates/refreshes the symlinks
```

## Skills

### Authored here

| Name | Description | Depends on |
| --- | --- | --- |
| [start-issue](skills/start-issue/) | Sets up a dedicated session for one issue — checks your existing branch, creates its worktree, moves in, starts the PRD, and leaves the hand-off record `/work-issue` continues from. | `using-git-worktrees`, `write-prd` |
| [work-issue](skills/work-issue/) | Runs the workflow on an issue `start-issue` set up — plans and implements in the session, delegates tests, mutation testing and both reviews to the isolated agents below, relays their questions, fixes the findings code-review first, and attaches the docs to the issue. | `start-issue`, `write-implementation-plan`, `implementation-loop`, `fix-review-findings`, the four agents |
| [start-pr-review](skills/start-pr-review/) | Sets up a dedicated session for one pull request — checks your local branch is at the PR head, creates its worktree, moves in, runs the PR review, and offers to remove the worktree afterwards. | `using-git-worktrees`, `pr-review` |
| [write-prd](skills/write-prd/) | Interviews the requester and grounds the result in the codebase to produce a PRD with scope, numbered requirements and Given/When/Then acceptance criteria, reviewed with you before hand-off. | — |
| [write-implementation-plan](skills/write-implementation-plan/) | Turns an issue or PRD into a technical plan: change list by layer, numbered requirements, ordered build sequence, rollback path. | `write-prd` (optional input) |
| [implementation-loop](skills/implementation-loop/) | Executes an implementation plan one phase at a time — implement, verify, suggest a commit, mark the phase done. | `write-implementation-plan` |
| [write-tests](skills/write-tests/) | Audits the existing coverage behavior by behavior, writes the missing unit tests (happy path, edge cases, error path) plus optional flow-based integration tests, and records the result in the plan. | `write-implementation-plan`, `implementation-loop` |
| [mutation-testing](skills/mutation-testing/) | Injects one deliberate defect at a time into the code under test and reports which mutants the suite killed, which survived, and the mutation score. | `write-tests` (optional input) |
| [code-review](skills/code-review/) | Reviews changed code for functional defects against the document it was built from, with severities and a merge-readiness score. | `write-prd` or `write-implementation-plan` |
| [refactor-review](skills/refactor-review/) | Reviews working code for behavior-preserving cleanups — duplication, misplaced helpers, convention drift, dead code — with a refactor score. | `write-implementation-plan`, `code-review` |
| [pr-review](skills/pr-review/) | Publishes a code review to a GitHub pull request — inline comments on the findings you pick plus one summary comment carrying the finding list and the merge-readiness score. | `code-review` |
| [fix-pr-review](skills/fix-pr-review/) | Triages the review comments on a pull request against the code and the plan, fixes the ones you pick one at a time, and replies to every comment — fixed and skipped alike. | `write-implementation-plan` or `write-prd` |
| [fix-review-findings](skills/fix-review-findings/) | Fixes the `code-review` / `refactor-review` findings you pick one at a time — verify, suggest a Conventional Commits title, and wait for your commit before starting the next. | `code-review`, `refactor-review` |
| [fix-merge-conflicts](skills/fix-merge-conflicts/) | Resolves the conflicts of a stopped rebase and stages them — one line per file on how each was fixed, anything ambiguous left unmerged for you, and `git rebase --continue` left to you. | — |
| [worktree-temp-task](skills/worktree-temp-task/) | Lends a worktree's branch and its uncommitted files to the main checkout for a task that only runs there, then puts the branch, the files and the main checkout's previous branch back — never deleting the worktree. | — |
| [english-coach](skills/english-coach/) | Appends a short English-coaching note to every response, rewriting the phrasings that read non-native. | — |

### External

Skills authored elsewhere and vendored in. `install.sh` links them like any other
skill, but they are not ours to maintain: fixes belong upstream, and edits here are
a deliberate local fork that the next update will have to be reconciled against.

| Name | Description | Origin |
| --- | --- | --- |
| [using-git-worktrees](skills/using-git-worktrees/) | Ensures feature work starts in an isolated workspace — detects existing isolation, prefers the harness's native worktree tool, falls back to `git worktree add`, then runs project setup and a baseline test. Pairs with `write-implementation-plan` / `implementation-loop`, which it is meant to run before. | Third-party, installed into `~/.agents/skills/`; upstream not recorded in `.skill-lock.json` |

## Agents

Subagents that run a verification skill in a context that did not write the code. Only
`/work-issue` delegates to them; invoking any of these skills by hand still runs it in-session,
as before. Each agent returns a `RESULT: OK | NEEDS_INPUT | BLOCKED` line followed by its
skill's own report, unchanged.

| Name | Wraps | Tools | Model · effort | Guard modes |
| --- | --- | --- | --- | --- |
| [code-reviewer](agents/code-reviewer.md) | `code-review` | Read, Grep, Glob, Bash | `claude-opus-5` · high | `readonly`, `skills-read` |
| [refactor-reviewer](agents/refactor-reviewer.md) | `refactor-review` | Read, Grep, Glob, Bash | `claude-opus-5` · high | `readonly`, `skills-read` |
| [tester](agents/tester.md) | `write-tests`, in an audit pass and a write pass | Read, Grep, Glob, Bash, Edit, Write | `sonnet` · high | `no-git`, `tests-only`, `skills-read` |
| [mutation-tester](agents/mutation-tester.md) | `mutation-testing` | Read, Grep, Glob, Bash, Edit | `sonnet` · medium | `no-git`, `src-only`, `skills-read` |

## Hooks

| Name | Description | Used by |
| --- | --- | --- |
| [agent-guard.sh](hooks/agent-guard.sh) | `PreToolUse` guard with five modes. `readonly` limits Bash to a read-only allowlist. `no-git` denies git commands that change state. `tests-only` and `src-only` limit which files Edit/Write may touch. `skills-read` lets an agent read the skill it wraps without a permission prompt. Fails closed, and needs `jq`. | Every agent, through its frontmatter `hooks:` |

## Setup on a new machine

```bash
git clone <this-repo> ~/Documents/Projects/CLAUDE.md
cd ~/Documents/Projects/CLAUDE.md
./install.sh
```

`install.sh` is idempotent. It backs up any real file it would replace to
`<name>.bak.<timestamp>`, and removes stale symlinks left behind by skills, agents
or hooks that were deleted from the repo.

The agents' guard hook needs `jq` on the `PATH`.

Set `CLAUDE_CONFIG_DIR` to link somewhere other than `~/.claude`. The agents' hook
commands still point at `$HOME/.claude/hooks/`, so with it set the guards do not run.

## Adding a skill

Create `skills/<name>/SKILL.md` here, add a row to the Skills table above, then run
`./install.sh` to link it. The `/write-skill` skill walks the whole process.

For a skill written by someone else, copy its folder into `skills/` and add the row
to the External table instead, recording where it came from.
