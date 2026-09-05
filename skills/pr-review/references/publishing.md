# Publishing the review to GitHub

Read when `scripts/submit-pr-review.sh` fails, when the user wants something the script does
not do (a reply, a second review, a comment on a file the PR deleted), or when you need to
undo what was posted.

## Why one review, not many comments

`POST /repos/{owner}/{repo}/pulls/{n}/reviews` with a `comments` array publishes the summary
and every inline comment as **one** event: one notification, one entry in the PR timeline,
one thread group the author can resolve. Posting findings one at a time
(`gh api .../pulls/{n}/comments`, or `gh pr comment` in a loop) sends N notifications and
leaves the summary unlinked to the lines it talks about. Always use the reviews endpoint.

The call is atomic: if one comment names a line outside the diff, GitHub returns 422 and
**none** of them is created. That is what the script's validation pass exists to prevent.

## The payload

```json
{
  "commit_id": "7adb2541716f52964d46143be7877d69c6d9f457",
  "event": "REQUEST_CHANGES",
  "body": "## Code review — 4 findings\n…",
  "comments": [
    { "path": "packages/api/src/charge.ts", "line": 88, "side": "RIGHT", "body": "…" },
    { "path": "packages/api/src/charge.ts", "start_line": 80, "start_side": "RIGHT",
      "line": 92, "side": "RIGHT", "body": "…" }
  ]
}
```

- `commit_id` — pin it to the head SHA you reviewed. Omitted, GitHub uses whatever HEAD is at
  submit time, so a push mid-review silently moves every comment.
- `line` / `side` — `RIGHT` numbers lines in the file at the head ref (added and context
  lines), `LEFT` numbers them in the base (removed and context lines). Comment on `LEFT` only
  when the finding is about code the PR deleted.
- `start_line` + `line` spans a range; both ends must be in the same hunk's diff.
- `event` — `REQUEST_CHANGES` is this skill's default. `COMMENT` posts without a verdict;
  `APPROVE` is never submitted by this skill.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| 422 `line must be part of the diff` | The line is not in a hunk, or it is on the wrong `side` | Re-run the script's `--dry-run`; it names the nearest commentable line. If none fits, move the finding into the summary body |
| 422 `Can not request changes on your own pull request` | You are the PR author | Re-run with `--event COMMENT` (the script exits 3 and says so) |
| 422 `commit_id is not part of the pull request` | The PR was force-pushed after you read the diff | Re-read the diff and the head SHA, re-validate every line, then resubmit |
| 403 / `Resource not accessible` | The token lacks write access to the repo | Report it; a fork PR from a read-only token cannot be reviewed this way |
| Comments show as "outdated" right after posting | The head moved between reading and posting | Nothing is lost, but resubmit against the new SHA if the lines changed |

## Things the script does not do

- **Reply in an existing thread**: `gh api --method POST repos/{repo}/pulls/{n}/comments \
  -f body='…' -F in_reply_to={comment_id}`.
- **A plain PR comment** (no lines, no verdict): `gh pr comment {n} --body-file body.md`.
- **Delete a review**: a *submitted* review cannot be deleted, only dismissed
  (`gh api --method PUT repos/{repo}/pulls/{n}/reviews/{review_id}/dismissals -f message='…'`,
  needs admin or write access, and the dismissal stays visible). Individual inline comments
  can be deleted: `gh api --method DELETE repos/{repo}/pulls/comments/{comment_id}`. This is
  why the confirmation gate before submitting is not optional.
- **Read back what was posted**: `gh pr view {n} --json reviews` and
  `gh api repos/{repo}/pulls/{n}/comments`.

## Suggestion blocks

A fenced ` ```suggestion ` block renders as a one-click "Commit suggestion" button, but only
when the comment's line range covers **exactly** the lines the block replaces. Use it when the
fix is a literal replacement of those lines; use a normal fenced code block for anything else
(a fix that touches another file, adds an import, or is longer than the commented span). A
`suggestion` block whose range is wrong applies silently wrong code — when in doubt, don't.
