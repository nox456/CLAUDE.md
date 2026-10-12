---
name: worktree-temp-task
description: Temporarily move a git worktree's branch, and its uncommitted work, into the main repository checkout so a task that only works there can run on it — stash the worktree's staged, unstaged and untracked files, detach and lock the worktree to free the branch, check the branch out in the main checkout with the files applied, hand over to the user, and on "done" reverse every step — files and branch back to the worktree, the main checkout back on its previous branch. Never deletes the worktree. Use when working in a worktree and the user says "run this in the main checkout", "check this branch out in the main repo", "move my branch to the main directory for a moment", "I need to test this from the main repo", "free the branch from the worktree", or invokes /worktree-temp-task — and again when they say the task is finished, "move it back", or "restore the worktree". Must be started from inside a linked worktree. Does not create worktrees — that is `using-git-worktrees`' ground.
compatibility: Requires git 2.31+ and a non-bare repository with a main checkout
---

# Lend a worktree's branch to the main checkout, then take it back

Two halves, run in two different turns: **Park** moves the branch and its uncommitted files from
the worktree into the main checkout and stops; **Restore** — only when the user says the task is
finished — puts everything back exactly where it was.

## Ground rules

- **Start only from a linked worktree.** Step 1 checks it. In the main checkout, or a worktree on
  a detached HEAD, stop and say so — there is no branch to lend.
- **Never delete the worktree.** It is detached and *locked*, not removed: no `git worktree
  remove`, no `prune`, no `ExitWorktree` with `remove`. Its directory, ignored files (`.env`,
  `node_modules`) and private git dir stay on disk, and the lock stops anything from pruning it.
- **One git command per Bash call, with literal absolute paths.** Write `git -C <WT> …` and `git
  -C <MAIN> …` with the real paths typed in — no `$(…)`, no shell variables, no `&&` chains
  around git. Claude Code's worktree guard refuses anything it cannot parse. Piping git's output
  into `grep`/`awk` is fine.
- **Stashes are shared by every worktree and session.** Only ever touch the entries carrying
  this run's tag. Never bare `git stash`, `pop`, or `stash@{0}`; apply by SHA, drop by the
  `stash@{n}` you just looked up by tag.
- **Drop nothing until everything is back.** The stashes are the safety net; they are dropped in
  the final step, after the worktree's state is verified.
- **The state file is the source of truth.** Write it in Step 2 and read it at the start of
  Restore — the conversation may have been compacted in between.

## Workflow

**Park** (one turn)
- [ ] Step 1 — Check the context and record the facts
- [ ] Step 2 — Stash the worktree's files and write the state file
- [ ] Step 3 — Free the branch: detach and lock the worktree
- [ ] Step 4 — Move to the main checkout and check the branch out there
- [ ] Step 5 — Hand over to the user

**Restore** (after the user says the task is finished)
- [ ] Step 6 — Take the files back out of the main checkout
- [ ] Step 7 — Put the main checkout back on its previous branch
- [ ] Step 8 — Re-attach the worktree and apply its files
- [ ] Step 9 — Verify, drop the stashes, report

---

### Step 1 — Check the context and record the facts

Run each from the worktree:

```bash
git rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel
git branch --show-current
git worktree list --porcelain
git status --short
```

- `--git-dir` equal to `--git-common-dir` means this is the main checkout, not a worktree: stop.
- Empty `branch --show-current` means a detached HEAD: stop.
- The **first** `worktree` entry of the porcelain list is the main checkout (`<MAIN>`); its
  `branch` line is `<PREV>` (if it says `detached`, `<PREV>` is its `HEAD` SHA). A `bare` line
  there means there is no main checkout: stop.
- `<WT>` is `--show-toplevel`, `<GITDIR>` is `--git-dir`, `<BRANCH>` is the current branch.

Then check the main checkout and the target branch:

```bash
git -C <MAIN> status --short
git -C <MAIN> worktree list
```

If `<MAIN>` has uncommitted changes of its own, they are set aside with their own tag in Step 4
and restored in Step 7 — note it. If `<BRANCH>` is already checked out by a *third* worktree,
stop and say which.

### Step 2 — Stash the worktree's files and write the state file

Pick the tag `wtt-<BRANCH>-<unix-seconds>` (`date +%s`), then:

```bash
git -C <WT> stash push --include-untracked -m "<TAG>:wt"
git stash list --format='%gd %H %gs' | grep -F "<TAG>:wt"
```

No line back means there was nothing to stash (git still exits 0 and prints "No local changes to
save") — record `WT_STASH=` empty, and never fall back to `stash@{0}`, which belongs to someone
else. Otherwise record the SHA.

Write `<GITDIR>/worktree-temp-task.env` with the Write tool:

```bash
TAG=<TAG>
WT=<WT>
MAIN=<MAIN>
BRANCH=<BRANCH>
PREV=<branch name, or SHA if MAIN was detached>
PREV_DETACHED=<yes|no>
WT_STASH=<sha or empty>
MAIN_STASH=<filled in Step 4>
RETURN_STASH=<filled in Step 6>
```

### Step 3 — Free the branch: detach and lock the worktree

```bash
git -C <WT> switch --detach
git -C <WT> worktree lock --reason "worktree-temp-task: state in <GITDIR>/worktree-temp-task.env" <WT>
```

The lock reason doubles as the pointer to the state file: `git worktree list --porcelain` shows
it, so Restore can find everything even if this conversation is gone.

### Step 4 — Move to the main checkout and check the branch out there

If this session entered the worktree through Claude Code's `EnterWorktree`, call
`ExitWorktree` with `action: "keep"` now — the guard refuses any git command aimed at `<MAIN>`
while the session is isolated. `keep` leaves the directory and branch on disk.

If `<MAIN>` had changes of its own (Step 1), stash them first and record the SHA as
`MAIN_STASH` in the state file:

```bash
git -C <MAIN> stash push --include-untracked -m "<TAG>:main"
git stash list --format='%gd %H %gs' | grep -F "<TAG>:main"
```

Then:

```bash
git -C <MAIN> switch <BRANCH>
git -C <MAIN> stash apply --index <WT_STASH>
git -C <MAIN> status --short
```

Skip the apply when `WT_STASH` is empty. `--index` keeps staged files staged; without it
everything lands unstaged. The status must match what Step 1 showed in the worktree.

### Step 5 — Hand over to the user

```markdown
`<BRANCH>` is checked out in `<MAIN>` with the worktree's uncommitted files applied. Go ahead
with the task there — commits on `<BRANCH>` are fine and come back with it.

Parked: `<WT>` (detached, locked). Main checkout was on `<PREV>`<; its own changes are stashed as `<TAG>:main`>.
Tell me when the task is finished and I'll move everything back.
```

End the turn there. Do not start Restore until the user says the task is finished.

### Step 6 — Take the files back out of the main checkout

Read `<GITDIR>/worktree-temp-task.env` first. If you lost track of it, `git worktree list
--porcelain` shows the path in the `locked` line.

```bash
git -C <MAIN> branch --show-current
```

If it is not `<BRANCH>`, stop and ask — the user switched away during the task, and the files in
the tree may not belong to this branch. Otherwise:

```bash
git -C <MAIN> stash push --include-untracked -m "<TAG>:return"
git stash list --format='%gd %H %gs' | grep -F "<TAG>:return"
```

Record the SHA as `RETURN_STASH` (empty when nothing was left). It holds the original files plus
whatever the task changed and did not commit.

### Step 7 — Put the main checkout back on its previous branch

```bash
git -C <MAIN> switch <PREV>
```

Use `git -C <MAIN> switch --detach <PREV>` when `PREV_DETACHED=yes`. If `MAIN_STASH` is set:

```bash
git -C <MAIN> stash apply --index <MAIN_STASH>
```

### Step 8 — Re-attach the worktree and apply its files

```bash
git -C <WT> worktree unlock <WT>
git -C <WT> switch <BRANCH>
git -C <WT> stash apply --index <RETURN_STASH>
```

Skip the apply when `RETURN_STASH` is empty. If the session left an `EnterWorktree` session in
Step 4, call `EnterWorktree` with `path: <WT>` now, so the session is back where it started.

### Step 9 — Verify, drop the stashes, report

```bash
git -C <WT> status --short
git -C <MAIN> status --short
```

The worktree must show its files again, and the main checkout its own state from before Park.
Only then drop each entry this run made, looking up its current index by tag right before each
drop — indexes shift after every drop:

```bash
git stash list --format='%gd %gs' | grep -F "<TAG>:"
git stash drop stash@{<n>}
```

Delete `<GITDIR>/worktree-temp-task.env`. Report in three lines: the branch is back in `<WT>`
with its files, `<MAIN>` is on `<PREV>`, and which stashes were dropped. If any apply conflicted,
drop nothing, leave the state file, and report the conflicted paths and the stash SHAs instead.

## Gotchas

- **`git switch <BRANCH>` in the main checkout fails with "already used by worktree"** until the
  worktree is detached. `switch --detach` is the cheapest way to free it — the worktree keeps its
  directory and HEAD commit.
- **`git stash push` on a clean tree exits 0 and creates nothing.** Reading `stash@{0}` afterwards
  silently picks up another session's stash. Always find the entry by its tag.
- **`git stash drop <sha>` errors with "is not a stash reference".** Apply takes a SHA; drop only
  takes `stash@{n}`.
- **Ignored files do not travel.** `--include-untracked` skips `.gitignore`d files (`.env`, build
  output) — the main checkout runs the task with its own copies. Never switch to `--all`; it
  would stash `node_modules`. If the task needs the worktree's `.env`, tell the user in Step 5.
- **`ExitWorktree` with `keep` returns the session to the directory it started in**, which is
  normally `<MAIN>`. Check with `git -C <MAIN> rev-parse --show-toplevel` before assuming.
