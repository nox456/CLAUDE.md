---
name: start-pr-review
description: Set up this Claude session to review one GitHub pull request in its own git worktree — confirm the PR, check the user's existing local branch for it is at the PR's head commit, create the worktree on it through the `using-git-worktrees` skill, move in, run `pr-review` on the PR, then offer to remove the worktree. Use when the user wants to review a PR in a worktree, review several PRs in parallel or alongside an issue, or says "start reviewing PR 42", "start a review of #42 on feat/x", "set up a worktree to review this PR", "spin up a workspace for this pull request", or invokes /start-pr-review. Requires a local branch the user already created for the PR (never main/master) and a session dedicated to that one PR. Never creates or updates a branch. For a review in the current checkout, use `pr-review` directly; to start work on an issue, use `start-issue`.
---

# Start a PR review in its own worktree

Puts this session in an isolated worktree on the user's local branch for one pull request, so
PRs can be reviewed side by side with other work, each in its own Claude session, then hands
over to `pr-review`. It prevents four failures: a review read from a stale branch, a branch the
user never asked for, the review run in a checkout that holds other work, and two PRs mixed into
one session.

## Ground rules

- **The user owns the branch.** Never create or move one: no `git branch`, no `git switch -c`,
  no `git checkout -b`, no `git worktree add -b`, no `gh pr checkout`, no `git pull`/`git merge`
  into it, and no `EnterWorktree` with `name`, which makes its own branch. If the branch is
  missing or stale, stop and tell the user the command to run.
- **Never `main`/`master`/the default branch.** Refuse it even when the user insists.
- **The branch must be at the PR head.** `pr-review` pins every comment to the PR's head SHA.
  A worktree on an older commit reviews code that is not in the PR.
- **One session, one PR.** This session belongs to the PR from Step 1 onwards. If it already
  holds work on something else (edited files, an issue, another PR or branch), stop and ask the
  user to open a fresh `claude` session and run `/start-pr-review` there.
- **Worktrees only through `using-git-worktrees`.** Never run `git worktree add` yourself. That
  skill owns directory choice, the gitignore check, project setup and the baseline tests.

## Workflow

- [ ] Step 1 — Confirm the session is dedicated
- [ ] Step 2 — Resolve the PR
- [ ] Step 3 — Check the branch
- [ ] Step 4 — Create the worktree through `using-git-worktrees`
- [ ] Step 5 — Move in and report
- [ ] Step 6 — Review the PR through `pr-review`
- [ ] Step 7 — Offer to remove the worktree

---

### Step 1 — Confirm the session is dedicated

Look back over this conversation. If earlier turns edited files, worked an issue, reviewed
another PR, or used another branch, stop with:

> This session already holds other work. Open a new `claude` session in the repo and run
> `/start-pr-review <pr> [branch]` there. One session per PR keeps the work apart.

A session that only asked questions or read files counts as fresh.

### Step 2 — Resolve the PR

If the user named no PR, ask for one. Do not infer it from the current branch. Read it:

```bash
gh pr view <n> --json number,title,url,state,headRefName,headRefOid,isCrossRepository,headRepositoryOwner
```

If it is merged or closed, or the lookup fails, say so and ask before going on. Record
`headRefOid` — the commit the review must see.

### Step 3 — Check the branch

`$BRANCH` is the branch the user named, or `headRefName` when they named none. From the main
checkout:

```bash
git fetch origin "pull/<n>/head"   # updates FETCH_HEAD only; creates no ref
git show-ref --verify --quiet "refs/heads/$BRANCH" && echo local
git rev-parse "refs/heads/$BRANCH"
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # default branch, e.g. origin/main
git worktree list --porcelain
```

| Finding | Action |
| --- | --- |
| `$BRANCH` is `main`, `master`, or the default branch | Refuse. Ask for the PR's branch |
| Not local | Stop. Ask the user to create it at the PR head: `git fetch origin pull/<n>/head:<BRANCH>` (works for fork PRs too) |
| Local, but `rev-parse` ≠ `headRefOid` | Stop. Show both SHAs. Ask the user to bring it to the PR head (`git fetch origin pull/<n>/head` then `git merge --ff-only FETCH_HEAD` on that branch). Do not do it yourself |
| Checked out in the main checkout | Stop. `git worktree add` refuses a branch checked out elsewhere. Ask the user to switch the main checkout to the default branch first. Do not switch it yourself |
| Already checked out in a linked worktree | Do not create another. Give the user its path and tell them to start the session there |
| Local, at `headRefOid`, and free | Continue |

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

Follow that skill to the end. If it creates the worktree on a branch other than `$BRANCH`, or
`git rev-parse HEAD` in the worktree is not `headRefOid`, stop and report it. Never `--force`
anything.

### Step 5 — Move in and report

From now on, run every command in the worktree. `cd` there in Bash and use absolute paths under
it for the Read tool. The main checkout is no longer this session's workspace.

Report:

```
PR:        #<n> — <title> (<url>)
Branch:    <branch> @ <short headRefOid>
Worktree:  <absolute path>
Baseline:  <tests passing | failures, as reported by using-git-worktrees>
```

A failing baseline is context for the user, not a review finding. Do not feed it to
`pr-review`.

### Step 6 — Review the PR

Still inside the worktree, invoke the `pr-review` skill with the Skill tool. Pass in `args`:

```
PR: #<n> (<url>), repo <owner/name>, head SHA <headRefOid>.
The current directory is a dedicated worktree on <BRANCH>, checked out at that head SHA.
Read the PR's files directly from it; skip `git fetch origin pull/<n>/head:pr-<n>`.
```

Follow that skill to the end, including its confirmation before anything is posted. A user who
declines to publish still ends the review.

### Step 7 — Offer to remove the worktree

Once `pr-review` hands off, ask whether to remove the review worktree. On no, give the path and
the command for later, and stop.

On yes, leave the worktree first, then remove it from the main checkout:

```bash
cd <main checkout>
git worktree remove "<worktree path>"
git worktree list
```

The branch stays — tell the user, and give `git branch -d <BRANCH>` if they want it gone.
If `git worktree remove` refuses (modified or untracked files), show its message and the
`git status --short` of the worktree, and leave it. Never `--force`.

Then stop. Offer a re-review after the author pushes; do not start one unasked.

## Gotchas

- `EnterWorktree` with `name` creates a new branch under `.claude/worktrees/` from
  `origin/<default>`. That is why Step 4 skips it, even though `using-git-worktrees` prefers it.
- `pr-review` normally reads files through `git fetch origin pull/<n>/head:pr-<n>`, which
  creates a local `pr-<n>` branch. The Step 6 override stops that; the worktree already holds
  the code.
- A local branch with the PR's name is often behind the PR: the author pushed after the user
  fetched. Step 3 compares SHAs instead of trusting the name.
- For a fork PR, `headRefName` is the fork's branch name and may collide with an unrelated local
  branch of the same name (`main`, `fix-typo`). The SHA check in Step 3 catches it.
- `git worktree add <path> <branch>` with a branch that exists only on `origin` silently creates
  a local tracking branch. Step 3 stops before that happens.
- `git worktree remove` succeeds even while the shell sits inside the worktree, leaving every
  later command in a deleted directory. `cd` to the main checkout first. It refuses on any
  untracked file, but gitignored setup output (`node_modules`, `.venv`) does not block it.
- Branch names with `/` (`feat/x`) give a nested worktree path (`.worktrees/feat/x`). That is
  expected.
