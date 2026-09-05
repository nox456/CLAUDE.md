---
name: pr-review
description: Review a GitHub pull request and publish the result as one review — inline comments on the findings the user picks, plus a summary comment with the full finding list and the merge-readiness score. Resolves what the PR is judged against (PRD, implementation plan, or the linked issue), delegates the correctness analysis to the `code-review` skill, and validates every comment against the diff before posting anything. Use when asked to "review this PR", "review PR #123", "leave comments on the pull request", "post/publish the review on GitHub", "request changes on this PR", or when invoked as /pr-review. Posts to GitHub, always with an explicit confirmation first — for a review that stays in the conversation and publishes nothing, use `code-review` instead.
---

# Review a Pull Request and Publish It

Turns a correctness review into a **published GitHub review**: inline comments on the lines the
user picked, plus one summary comment carrying the finding list and the merge-readiness score.
The analysis itself is `code-review`'s job — this skill owns resolving what the PR is judged
against, choosing what belongs on a line, and getting it onto GitHub without a rejected payload
or a stream of notifications.

## Ground rules

- **Nothing reaches GitHub until the user has seen it and said yes.** A submitted review
  notifies every subscriber and cannot be deleted, only dismissed. Show the exact body and the
  exact inline comments, wait for an explicit go-ahead, then post (step 6).
- **One review, one API call.** Everything ships through
  `scripts/submit-pr-review.sh`, which posts a single review. Never loop `gh pr comment` or
  `gh api .../pulls/{n}/comments` over the findings.
- **The findings are `code-review`'s, unedited.** Do not add findings, re-word severities, or
  re-score. This skill reformats them for GitHub and nothing else.
- **Read-only on the working tree.** No code edits, no test runs, and never `gh pr checkout` —
  it moves the user's branch. Read PR files with
  `git fetch origin pull/<n>/head:pr-<n>` then `git show pr-<n>:<path>`.
- **Every inline comment must land on a line in the diff.** GitHub rejects the *whole* review
  over one bad line, so the dry-run gate in step 6 is not optional.

## Workflow

- [ ] Step 1 — Identify the PR and resolve the scope
- [ ] Step 2 — Load the document the PR is judged against
- [ ] Step 3 — Get the findings from `code-review`
- [ ] Step 4 — Split the findings into inline and summary
- [ ] Step 5 — Write `body.md` and `comments.json`
- [ ] Step 6 — Dry-run, confirm, submit

---

### Step 1 — Identify the PR and resolve the scope

Use the number or URL the user gave. With none, infer it from the current branch:

```bash
gh pr view --json number,title,url,headRefOid,baseRefName,author,body,isCrossRepository
```

If the branch has no PR, stop and say so — this skill publishes to a PR, so without one there
is nothing to publish to; offer `/code-review` instead.

Record the **head SHA** (`headRefOid`) and the **PR author**. Everything downstream — the line
numbers, the review payload, the choice of event — is pinned to that SHA, and the author
decides whether `REQUEST_CHANGES` is even allowed (see Gotchas). Then read the patch:

```bash
gh pr diff <n> --repo <owner/name>
```

### Step 2 — Load the document the PR is judged against

Find the yardstick, in this order, and stop at the first that exists:

1. **A path the user named.**
2. **A PRD or implementation plan in the repo** — search by content, not filename:
   ```bash
   rg -l --iglob '*.md' -e '^# PRD' -e 'Implementation Plan' -e 'Acceptance criteria'
   ```
   then check `docs/plans/`, `docs/`, and the repo root.
3. **A plan or PRD linked from the PR body or the linked issue** — follow the link and read it.
4. **The linked issue itself.** Get it with `gh issue view <n>` (the number comes from the PR
   body's `Closes #n` / `Fixes #n`, or `gh pr view <n> --json closingIssuesReferences`).

Landing on 4 is a degraded review and must be handled as one:

- Say so to the user before continuing, and again in the published summary — an issue states
  intent, not numbered requirements or contracts, so requirement traceability is best-effort.
- `code-review` will refuse an issue as its document (that gate is deliberate). Do not
  reformat the issue into a fake plan to get past it. Run the analysis in this session instead,
  under `code-review`'s own rules: read the two files it bundles — `analysis-passes.md` for the
  four passes, `review-checklist.md` for the finding format, severity anchors and score — from
  its installed directory, `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/code-review/`. Same rules,
  applied against the issue.

With nothing at all — no document, no linked issue, an empty PR body — stop and offer
`/write-implementation-plan`. A review with no yardstick can only say the code is
self-consistent.

### Step 3 — Get the findings from `code-review`

Invoke the `code-review` skill (Skill tool, `skill: code-review`), handing it the PR number and
the document path from step 2, e.g. `review PR #412 against docs/plans/0031-refunds.md`.

It returns numbered findings in the five-line format — title, `Severity`, `Location`,
`Description`, `Suggestion` — sorted by severity, plus the score arithmetic and the verdict
band. Take that output as given; step 4 only sorts it.

Its `Location` values are already line numbers in the file **at the reviewed ref**, which is
exactly what the GitHub API wants for `side: RIGHT`. Do not recompute them from diff hunk
headers.

### Step 4 — Split the findings into inline and summary

A finding goes **inline** when it points at one file and its line is inside a diff hunk;
otherwise it goes in the summary body only. `Multiple locations:` findings, missing
requirements, and findings on lines the PR did not touch are summary-only by construction.

Propose this default split and ask the user to confirm or adjust — do not decide alone:

| Findings | Default |
| --- | --- |
| BLOCKING, HIGH | Inline |
| MEDIUM, LOW | Summary body |
| Anything with no single diff line | Summary body (not negotiable) |

Present it as a compact table — number, severity, title, `path:line`, and `inline` or
`summary` — and take their edits before writing anything.

### Step 5 — Write `body.md` and `comments.json`

Write both files to the scratchpad directory, not the repo.

**`body.md`** — fill `assets/review-body.md`. Every finding appears here, inline ones as a
one-line entry (severity, title, `path:line`) and summary-only ones in their full five-line
form. The score arithmetic, the cap, and the verdict are copied from step 3 unchanged.

**`comments.json`** — a JSON array, one object per inline finding:

```json
[
  {
    "path": "packages/api/src/payments/charge.ts",
    "line": 112,
    "start_line": 88,
    "body": "**BLOCKING — Retry loop re-charges the card on a timeout**\n\nThe retry wraps the whole `chargeCard` call instead of the response read, so a gateway timeout after a successful authorization charges the customer twice.\n\n**Suggestion:** pass the idempotency key the plan's Contracts section defines:\n\n```ts\nawait gateway.charge({ ...payload, idempotencyKey: intent.id })\n```"
  }
]
```

- `body` carries the finding's severity and title in bold, then its Description, then its
  Suggestion. Same words as step 3 — the inline comment is a re-layout, not a rewrite.
- `start_line` is optional and spans a range; use it when the defect covers a block.
- `side` defaults to `RIGHT`. Set `"side": "LEFT"` only for a finding about a line the PR
  deleted.
- Use a ` ```suggestion ` block **only** when the fix replaces exactly the commented lines —
  otherwise a plain fenced block. See `references/publishing.md`.

### Step 6 — Dry-run, confirm, submit

Validate first. This never posts:

```bash
scripts/submit-pr-review.sh --pr <n> --repo <owner/name> \
  --body-file <scratch>/body.md --comments-file <scratch>/comments.json --dry-run
```

It rejects any comment whose line is outside the diff and names the nearest commentable line.
Fix by retargeting the comment or moving that finding into the summary, then re-run until it
prints `OK: payload valid`. Read `references/publishing.md` if a failure is not obviously one
of those two.

Then **show the user** the rendered `body.md` and each inline comment with its `path:line`, and
ask for an explicit go-ahead. Only after they give it:

```bash
scripts/submit-pr-review.sh --pr <n> --repo <owner/name> \
  --body-file <scratch>/body.md --comments-file <scratch>/comments.json --confirm
```

`--confirm` is what makes it post; without it (and without `--dry-run`) the script exits 2 and
contacts nothing. The event is `REQUEST_CHANGES`. On exit code 3 (GitHub refuses that on your own PR), tell the
user and re-run with `--event COMMENT` once they agree.

Close with the review URL the script prints, the counts per severity, how many landed inline,
and the score and band. Then stop — offer `refactor-review` for the cleanup pass, or a
re-review after fixes; run neither unasked.

## Gotchas

- **You cannot `REQUEST_CHANGES` or `APPROVE` your own PR.** GitHub returns 422; the script
  exits 3 with the message. Check `author.login` from step 1 against `gh api user -q .login`
  before the run so this is not a surprise at the end.
- **A review is atomic.** One inline comment on a line outside the diff and GitHub creates
  none of them — not the other comments, not the summary. Never skip `--dry-run`.
- **Only lines inside a hunk are commentable**, including its context lines — not the whole
  file. A defect on an untouched line 400 of a file whose diff stops at line 60 has no inline
  home; it goes in the summary.
- **A submitted review cannot be deleted**, only dismissed, and the dismissal stays in the
  timeline. Individual inline comments can be deleted afterwards; the summary cannot. Re-running
  the script with `--confirm` posts a *second* review rather than replacing the first.
- **A force-push invalidates the whole payload.** The pinned `commit_id` is rejected and the
  line numbers have moved. Re-read the diff and rebuild `comments.json` — do not retarget by
  hand.
- **Diff hunk headers are not file line numbers.** `code-review` already gives ref-based lines;
  if you ever compute one yourself, open the file at the head ref and count.
- **`gh pr diff` shows the merge diff for cross-repo PRs too**, but a token without write
  access to the base repo cannot post the review at all — check `isCrossRepository` early.
- Both `code-review` and this skill answer "review this PR". This one is the right choice only
  when the result is meant to end up **on GitHub**; when the user wants the findings in the
  conversation, hand off to `/code-review` and stop.
