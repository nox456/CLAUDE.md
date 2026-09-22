---
name: fix-merge-conflicts
description: Resolve the conflicts of an in-progress git rebase and stage the resolutions — inventory the conflicted files, read what the replayed commit was trying to do, resolve each hunk, check no conflict markers survive, stage only what was conflicted, and report a short per-file summary of how each was fixed. Leaves a genuinely ambiguous conflict unstaged and asks instead of guessing, and never commits or runs `git rebase --continue` — finishing the rebase is the user's call. Use when a rebase has stopped on a conflict, or when the user says "fix the merge conflicts", "resolve these conflicts", "fix the rebase", "the rebase is stuck", "help me through this rebase", "sort out the conflicts and stage them", or invokes /fix-merge-conflicts. Requires a rebase already in progress; does not handle `git merge`, cherry-pick, revert, stash-pop, or `git am` conflicts.
compatibility: Requires git, and a rebase already stopped on a conflict in the working repository
---

# Resolve the conflicts of the stopped rebase

Resolve every conflicted file of the rebase that is currently paused, stage the resolutions, and
hand back a short per-file summary. Continuing the rebase stays with the user, always.

## Ground rules

- **A rebase must already be in progress.** Verify it in Step 1. If there is none, stop and say
  what the repository is actually in (clean, a merge conflict, a cherry-pick) — never start a
  rebase, and never resolve a conflict this skill does not cover.
- **Never end the rebase.** No `git commit`, no `git rebase --continue`, `--skip` or `--abort`,
  no `git push`, no branch switching. The user reviews the staged resolution and continues.
  Finish by *telling* them the command, not running it.
- **Resolve toward the replayed commit's intent.** A rebase applies one commit at a time onto a
  new base. The right resolution is "what this commit was trying to do, expressed on top of the
  new base" — not what the branch should look like at the end of the series. Later commits in
  the series will bring their own changes; stealing their work into this one corrupts the
  history the user is building.
- **Ambiguity is escalated, not guessed.** When both sides changed the same logic and either
  resolution could be the wrong one, leave that file out of the index and ask the user, after
  every unambiguous file is resolved and staged.
- **Touch only conflicted files.** Never `git add -A`, `git add .`, or `git add -u` — a rebase
  stop often coexists with unrelated working-tree edits, and sweeping them in silently puts them
  inside someone else's commit. Stage by explicit path.

## Workflow

- [ ] Step 1 — Confirm the rebase and inventory the conflicts
- [ ] Step 2 — Read the intent behind each conflict
- [ ] Step 3 — Resolve file by file
- [ ] Step 4 — Verify the resolutions
- [ ] Step 5 — Stage only what was conflicted
- [ ] Step 6 — Report and hand back

---

### Step 1 — Confirm the rebase and inventory the conflicts

Run exactly this, and read all of it before touching a file:

```bash
test -d "$(git rev-parse --git-path rebase-merge)" || test -d "$(git rev-parse --git-path rebase-apply)" \
  && echo "REBASE IN PROGRESS" || echo "NO REBASE"
git status                                    # the banner names the rebase and the step
git log -1 --format='%h %s%n%n%b' REBASE_HEAD # the commit being replayed
git status --porcelain                        # the conflicts, with their two-letter codes
git config --get merge.conflictStyle          # empty, "diff3" or "zdiff3"
```

`NO REBASE` is a hard stop: report what the repository is in and end the run.

Read the porcelain codes rather than assuming every conflict has markers in a file:

| Code | Means | Resolved by |
| --- | --- | --- |
| `UU` | both sides edited the file | editing the markers (Step 3) |
| `AA` | both sides added the same path | editing the markers, usually keeping both |
| `UD` | your commit deleted it, the new base modified it | deciding: `git rm` it, or keep the base's version |
| `DU` | your commit modified it, the new base deleted it | same decision, mirrored |
| `AU` / `UA` | added on one side only, in a rename/add clash | read `references/tricky-conflicts.md` |
| `DD` | both sides deleted it | `git rm -- <path>` |

For anything that is not `UU` or `AA`, or for a lockfile, a generated file, a binary, or a
submodule, read `references/tricky-conflicts.md` before resolving it.

### Step 2 — Read the intent behind each conflict

Never resolve from the markers alone — they show two texts, not two intentions. For each
conflicted file:

```bash
git show REBASE_HEAD -- <path>          # what the replayed commit changes in this file
git log --oneline -3 HEAD -- <path>     # what the new base recently did to it
```

Then read the conflicted file itself. You are looking for whether the two sides are orthogonal
(both changes belong in the result), overlapping (one supersedes the other), or contradictory
(they cannot both hold — the ambiguous case).

### Step 3 — Resolve file by file

Edit the file directly, deleting the `<<<<<<<`, `=======` and `>>>>>>>` lines along with any
side you drop. Default resolutions:

- **Orthogonal changes** (different concerns in one hunk — an import added on one side, a
  parameter renamed on the other): keep both, merged into coherent code.
- **The base already did what the commit does** (a fix landed upstream): keep the base's version.
- **The commit supersedes the base** in the area it touches: keep the commit's version, and
  re-apply anything the base added that the commit was not aware of.
- **Whole-file take**, only when the entire file should come from one side:
  `git checkout --theirs -- <path>` takes the replayed commit's version; `--ours` takes the new
  base's. See the Gotchas — this pair is inverted from what "ours" means outside a rebase.

When the resolution is genuinely ambiguous — both sides changed the same logic, and picking
wrong is a silent behavior change — **stop on that file**: leave it conflicted, do not edit
around it, do not stage it, and carry it to Step 6 as a question. Keep resolving the others.

If you mangle a file while editing, restore its conflicted state with
`git checkout --merge -- <path>` and start it over.

### Step 4 — Verify the resolutions

Static checks only — no test suite, no build of the whole project.

```bash
grep -nE '^(<<<<<<<|>>>>>>>|\|\|\|\|\|\|\|)' -- <every file you resolved>
```

Empty output is the pass. A hit means a marker survived — fix it and re-run. (`=======` is
deliberately not in that pattern: it is a legitimate line in Markdown and reST. Check it by eye
in those files.)

Then, if the repo has a cheap check for the file's language that runs on single files — a
formatter's `--check`, a linter, a typechecker, `python -m py_compile`, `node --check` — run it
on the resolved files only. If it needs the whole project or a running suite, skip it and say so
in the report; that verification is the user's to run.

### Step 5 — Stage only what was conflicted

```bash
git add -- <path> <path>      # name every resolved file explicitly
git status --porcelain        # confirm what is staged and what is deliberately left
```

Expect every resolved file to show as staged and nothing else to have moved. Files you left
ambiguous must still show as unmerged — if one is staged, unstage it and flag it.

### Step 6 — Report and hand back

Keep it short — one line per file, no diffs, no narration of the steps.

```markdown
Resolved <n> of <total> conflicts in `<short-sha> <commit subject>` (step X/Y of the rebase).

- `path/to/file.ts` — kept both: the base's new `retry` import plus this commit's rename to `sendBatch`.
- `path/to/other.py` — took this commit's version; the base's change to the same block was a fix it already includes.
- `lock/file.json` — regenerated with `<command>` instead of hand-merging.

**Needs your decision**
- `path/to/hard.ts` — left unmerged. The base changed the timeout to 30s; this commit changed the
  same call to retry three times. Which behavior should survive?

Staged: `file.ts`, `other.py`, `lock/file.json`. Not staged: `hard.ts`.
Checked: no conflict markers remain; `<check you ran>` passes. Tests not run.

Continue the rebase yourself when you are happy with the resolution: `git rebase --continue`.
```

If any file is left unmerged, the report ends with the question — do not run further commands
after asking.

## Gotchas

- **`--ours` and `--theirs` are inverted during a rebase.** `--ours`/the `HEAD` side is the
  *upstream* branch you are rebasing onto; `--theirs`/the `REBASE_HEAD` side is *your own*
  commit being replayed. Reading them the intuitive way keeps the wrong half every time.
- **`git rev-parse --git-path rebase-apply` prints a path whether or not it exists.** Test the
  directory with `test -d`, never the command's success. (It also resolves correctly inside a
  linked worktree, where `.git` is a file — which is why the check never hardcodes `.git/`.)
- **`git status --short` does not say a rebase is running.** It shows `## HEAD (no branch)`. Use
  the long `git status` for the banner and the step counter.
- **`git add` accepts a file with conflict markers still in it, silently.** The index is then
  "resolved" and the markers reach the commit. Step 4's grep is the only thing preventing this;
  run it before staging, never after.
- **With `merge.conflictStyle = diff3` or `zdiff3` there is a third section**, between `|||||||`
  and `=======`: the merge *base*, i.e. the common ancestor. It is context for deciding, never a
  side to keep — leaving it in the file is a silent revert to old code.
- **`git rerere` can pre-resolve a file from a past resolution.** If a conflicted file already
  looks merged and clean, that is rerere, not luck: `git rerere status` and `git rerere diff`
  show what it did. Review it like any other resolution — a stale recorded resolution is exactly
  how a wrong merge repeats itself.
- **A conflict can be zero-hunk.** `UD`/`DU`/`DD` files have no markers anywhere; only the
  porcelain code reveals them. Resolving "all the markers in the tree" leaves the rebase stuck.
- **`REBASE_HEAD` exists only while the rebase is stopped.** Read what you need from it before
  anything that could advance the rebase; once it continues, the reference is gone.
