# Conflicts that are not two blocks of text

Read this when `git status --porcelain` shows anything other than `UU` or `AA`, or when the
conflicted path is a lockfile, a generated file, a binary, or a submodule. Everything here
assumes a rebase is in progress, so `--ours` is the new base and `--theirs` is the commit being
replayed.

## The three stages of a conflicted path

Every unmerged path has up to three blobs in the index, and they are readable without touching
the working tree:

```bash
git ls-files -u -- <path>     # which stages exist: 1 base, 2 ours/new base, 3 theirs/your commit
git show :1:<path>            # the common ancestor
git show :2:<path>            # the new base's version
git show :3:<path>            # the replayed commit's version
```

A missing stage *is* the information: no stage 1 means both sides added the path
independently; no stage 2 means the new base deleted it; no stage 3 means the replayed commit
deleted it. Use this to read a binary or a mangled file without guessing.

## Delete/modify — `UD`, `DU`

`UD`: the replayed commit deleted the file, the new base modified it. `DU` is the mirror.

This is never resolvable from the text. Establish *why* each side acted:

```bash
git log -1 --format='%h %s%n%n%b' REBASE_HEAD    # did this commit delete it on purpose?
git log --oneline -3 HEAD -- <path>              # what did the base change, and why?
```

- The commit deleted the file because its content moved elsewhere → `git rm -- <path>`, and
  check whether the base's modification needs porting to the new location. If it does and the
  destination is not conflicted, that is an ambiguity: leave it and ask.
- The base's modification is substantial or recent (a security fix, a migration) → the deletion
  is probably stale. Keep the file (`git add -- <path>` after confirming its content is the
  base's) and say so in the report.
- Anything less clear-cut → leave it unmerged and ask. A wrongly deleted file is silent.

## Both deleted — `DD`

Both sides removed the path. Resolve with `git rm -- <path>`; there is nothing to decide.

## Add/add and rename clashes — `AA`, `AU`, `UA`

`AA` is two independent additions of the same path — resolve like `UU`, but check for a
duplicated definition: the naive "keep both" often produces the same function twice.

`AU`/`UA` usually mean a rename raced an edit. Find the other end before deciding:

```bash
git show --stat --find-renames REBASE_HEAD       # did this commit rename the file?
git log --oneline -3 --find-renames HEAD -- <path>
```

Resolve toward the rename's destination: the content belongs at the new path, carrying both
sides' edits. If the destination file is not itself conflicted, editing it is outside this
conflict — do it, and name it explicitly in the report.

## Lockfiles and generated files

Never hand-merge a lockfile, a compiled asset, a snapshot, or anything with a
"generated — do not edit" header. Merging them by hand produces a file that is internally
inconsistent and passes review.

Take the replayed commit's manifest side, then regenerate:

| File | Regenerate with |
| --- | --- |
| `package-lock.json` | `npm install --package-lock-only` |
| `pnpm-lock.yaml` | `pnpm install --lockfile-only` |
| `yarn.lock` | `yarn install --mode update-lockfile` (Yarn 1: `yarn install`) |
| `bun.lock` | `bun install --lockfile-only` |
| `Cargo.lock` | `cargo generate-lockfile` |
| `poetry.lock` | `poetry lock` (Poetry 1.x: `poetry lock --no-update`) |
| `uv.lock` | `uv lock` |
| `go.sum` | `go mod tidy` |
| anything else generated | the repo's own build/codegen command |

Resolve the *source* first — `package.json`, `Cargo.toml`, `pyproject.toml`, the schema — then
regenerate the artifact from the resolved source, then stage both. If the regeneration command
is not available in this environment, say so in the report and leave the lockfile unstaged
rather than committing a hand-edited one.

## Binaries

A binary conflict has no useful text form. Pick a side whole:

```bash
git checkout --theirs -- <path>   # the replayed commit's version
git checkout --ours   -- <path>   # the new base's version
```

Choose by intent, read from the two commits' messages — and when the file is one a human
authored (an image, a PDF, a fixture), prefer asking over picking. Note the choice in the report
either way; a silently replaced binary is invisible in review.

## Submodules

A conflicted submodule is a conflict over *which commit* the parent should point at. Do not
enter the submodule and merge inside it.

```bash
git ls-files -u -- <submodule-path>    # the two candidate SHAs, stages 2 and 3
git -C <submodule-path> log --oneline --left-right --boundary <sha2>...<sha3>
```

If one SHA is an ancestor of the other (`git -C <sub> merge-base --is-ancestor A B`), the
descendant is almost always right: `git update-index --cacheinfo 160000,<sha>,<path>`, or the
simpler `git checkout --theirs -- <path>` / `--ours` when the side matches. If the two have
diverged, the parent repo cannot decide it — leave it unmerged and ask.

## When the working tree is already wrong

To get a conflicted file back to its original conflicted state, markers and all:

```bash
git checkout --merge -- <path>
```

With `git checkout --conflict=diff3 -- <path>` it comes back showing the merge base in a third
section, which is often what makes a stubborn conflict readable.
