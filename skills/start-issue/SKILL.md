---
name: start-issue
description: Set up this Claude session to work one issue in its own git worktree — confirm the issue (GitHub or Linear), check the user's existing branch, create the worktree on it through the `using-git-worktrees` skill, move in, then run `write-prd` on the issue. Use when the user wants to start an issue in a worktree, work several issues in parallel, or says "start issue 42", "start LIN-123 on feat/x", "set up a worktree for this issue", "new worktree for my branch", "spin up a workspace for this ticket", or invokes /start-issue. Requires a branch the user already created (never main/master) and a session dedicated to that one issue. Never creates a branch. Stops after the PRD and leaves a hand-off record that `/work-issue` requires to continue the issue.
---

# Start an issue in its own worktree

Puts this session in an isolated worktree on a branch the user already created, tied to one
issue, so several issues can run side by side, each in its own Claude session. It prevents
three failures: work landing on `main`, a branch the user never asked for, and two issues
mixed into one session.

## Ground rules

- **The user owns the branch.** Never create one: no `git branch`, no `git switch -c`, no
  `git checkout -b`, no `git worktree add -b`, and no `EnterWorktree` with `name`, which makes
  its own branch. If the branch is missing, stop and ask the user to create it.
- **Never `main`/`master`/the default branch.** Refuse it even when the user insists. A worktree
  on the default branch defeats the isolation.
- **One session, one issue.** This session belongs to the issue from Step 1 onwards. If it
  already holds work on something else (edited files, another issue, another branch), stop and
  ask the user to open a fresh `claude` session and run `/start-issue` there.
- **Worktrees only through `using-git-worktrees`.** Never run `git worktree add` yourself. That
  skill owns directory choice, the gitignore check, project setup and the baseline tests.

## Workflow

- [ ] Step 1 — Confirm the session is dedicated
- [ ] Step 2 — Resolve the issue
- [ ] Step 3 — Check the branch
- [ ] Step 4 — Create the worktree through `using-git-worktrees`
- [ ] Step 5 — Move in and report
- [ ] Step 6 — Write the PRD through `write-prd`

---

### Step 1 — Confirm the session is dedicated

Look back over this conversation. If earlier turns edited files, worked another issue, or used
another branch, stop with:

> This session already holds other work. Open a new `claude` session in the repo and run
> `/start-issue <issue> <branch>` there. One session per issue keeps the work apart.

A session that only asked questions or read files counts as fresh.

### Step 2 — Resolve the issue

If the user named no issue, ask for one. Do not infer it from the branch name. Read the issue
to confirm it exists and to get its title:

- **GitHub** (`#42`, `42`, or a URL): `gh issue view <n> --json number,title,state,url`
- **Linear** (`ABC-123` or a URL): use the Linear MCP tools if they are connected. If they are
  not, ask the user to paste the title and keep the ID as they gave it.

If the issue is closed, or the lookup fails, say so and ask before going on.

### Step 3 — Check the branch

If the user named no branch, ask for one. Then, from the main checkout:

```bash
git show-ref --verify --quiet "refs/heads/$BRANCH" && echo local
git show-ref --verify --quiet "refs/remotes/origin/$BRANCH" && echo remote
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # default branch, e.g. origin/main
git worktree list --porcelain
```

| Finding | Action |
| --- | --- |
| `$BRANCH` is `main`, `master`, or the default branch | Refuse. Ask for a feature branch |
| Not local and not remote | Stop. Ask the user to create it (for example `git branch <name> main`) |
| Remote only | Stop. Ask the user to create the local branch (`git branch --track <name> origin/<name>`). `git worktree add` would create one implicitly, and that counts as creating a branch |
| Checked out in the main checkout | Stop. `git worktree add` refuses a branch that is checked out elsewhere. Ask the user to switch the main checkout back to the default branch first. Do not switch it yourself |
| Already checked out in a linked worktree | Do not create another. Give the user its path and tell them to start the session there |
| Local and free | Continue |

### Step 4 — Create the worktree through `using-git-worktrees`

Invoke the `using-git-worktrees` skill with the Skill tool and pass these overrides in `args`.
They take precedence over its defaults:

```
Consent is given: create the worktree without asking.
Branch: <BRANCH>. It already exists. Do NOT create a branch.
Skip Step 1a (native tools): EnterWorktree always creates a new branch.
Use Step 1b with the existing branch and no -b:  git worktree add "<location>/<BRANCH>" "<BRANCH>"
Run Steps 2 and 3 (project setup, baseline tests) inside the new worktree.
```

Follow that skill to the end. If it creates the worktree on a branch other than `$BRANCH`,
stop and report it. Never `--force` anything.

### Step 5 — Move in and report

From now on, run every command and file edit in the worktree. `cd` there in Bash and use
absolute paths under it for the Read, Edit and Write tools. The main checkout is no longer this
session's workspace.

Report:

```
Issue:     <ID> — <title> (<url>)
Branch:    <branch>
Worktree:  <absolute path>
Baseline:  <tests passing | failures, as reported by using-git-worktrees>
```

Then, from inside the worktree, write the hand-off record. `/work-issue` refuses to run
without it. It goes in the worktree's private git directory, so it is never committed and is
removed along with the worktree:

```bash
jq -n --arg issue "<ID>" --arg tracker "<github|linear>" --arg title "<title>" --arg url "<url>" \
  --arg branch "<BRANCH>" --arg worktree "$(git rev-parse --show-toplevel)" --arg created "$(date +%F)" \
  '{issue: $issue, tracker: $tracker, title: $title, url: $url, branch: $branch,
    worktree: $worktree, prd: null, plan: null, created: $created}' \
  > "$(git rev-parse --absolute-git-dir)/start-issue.json"
```

### Step 6 — Write the PRD

Still inside the worktree, invoke the `write-prd` skill with the Skill tool on the issue from
Step 2. Pass the issue ID, title and URL in `args` so it does not ask for them again. Follow
that skill to the end, including its review with the user.

When `write-prd` hands off, store the PRD's absolute path in the record:

```bash
f="$(git rev-parse --absolute-git-dir)/start-issue.json"
jq --arg prd "<absolute PRD path>" '.prd = $prd' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
```

Then stop, and offer `/work-issue` as the next step. It continues from this record, in this
session or a later one opened in the worktree. Do not start it, the implementation plan or any
code until the user asks.

## Gotchas

- `EnterWorktree` with `name` creates a new branch under `.claude/worktrees/` from
  `origin/<default>`. That is why Step 4 skips it, even though `using-git-worktrees` prefers it.
- `git worktree add <path> <branch>` with a branch that exists only on `origin` silently creates
  a local tracking branch. Step 3 stops before that happens.
- A user who ran `git checkout -b feat/x` has that branch checked out in the main checkout, and
  `git worktree add` fails with "already checked out". This is the most common case. Catch it in
  Step 3, not from the error.
- Branch names with `/` (`feat/x`) give a nested worktree path (`.worktrees/feat/x`). That is
  expected.
