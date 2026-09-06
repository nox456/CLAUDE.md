# The PR comment API

Read when `scripts/fetch-pr-comments.sh` or `scripts/submit-replies.sh` fails, when you need
something they do not do, or when you have to undo a reply.

## The three sources, and what each one can carry

| Source | Endpoint | Has a thread | Reply with |
| --- | --- | --- | --- |
| Inline review comments | `GET /repos/{r}/pulls/{n}/comments` | Yes | `POST /repos/{r}/pulls/{n}/comments/{root_id}/replies` |
| Review summary bodies | `GET /repos/{r}/pulls/{n}/reviews` | No | A conversation comment quoting it |
| Conversation comments | `GET /repos/{r}/issues/{n}/comments` | No | A conversation comment quoting it |

A pull request *is* an issue, which is why its top-level comments live under `/issues/`. Only
the inline endpoint knows about files and lines.

`fetch-pr-comments.sh` merges all three, drops the noise (see below), and hands back one array.
Reach for the raw endpoints only when it fails.

## Fields that are not what they look like

- **`line` is `null` on an outdated comment.** GitHub nulls `line`, `start_line` and `position`
  once the commented lines move. `original_line` and `original_commit_id` still hold where it
  was pointed when written, and `diff_hunk` carries the code it quoted. The fetch script sets
  `outdated: true` and leaves `line` null rather than guessing a current line.
- **`in_reply_to_id`** separates the root of a thread from the replies inside it. Only the root
  accepts a reply; posting to a reply's id is rejected. The fetch script returns roots only and
  counts the rest in `reply_count`.
- **`subject_type`** is `line` or `file`. A `file` comment has no line at all and never will.
- **Bot logins differ per endpoint** for the same reviewer — Copilot is `Copilot` on the review
  comments endpoint, `copilot-pull-request-reviewer[bot]` on the reviews endpoint and
  `copilot-pull-request-reviewer` in GraphQL. `user.type == "Bot"` is the only stable test.
- **Empty review bodies are structural.** Replying in a thread creates a `COMMENTED` review with
  `body: ""` to hold the reply. They are not feedback; the fetch script drops them.
- **`state: "PENDING"`** is a review its author has not submitted. Only they can see it — never
  triage or reply to one.

## Thread ids live only in GraphQL

REST has no field for the thread node id (`PRRT_…`), which is what `resolveReviewThread` needs.
Get it, and the resolution state, by joining on the root comment's `databaseId`:

```bash
gh api graphql -f query='
query($owner:String!,$name:String!,$pr:Int!){
  repository(owner:$owner,name:$name){ pullRequest(number:$pr){
    reviewThreads(first:100){ nodes{
      id isResolved isOutdated path line
      comments(first:1){ nodes{ databaseId } } } } } }
}' -f owner=OWNER -f name=NAME -F pr=N
```

Resolve one (this is what `--resolve` does per entry):

```bash
gh api graphql -f query='mutation($id:ID!){
  resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' -f id=PRRT_…
```

`unresolveReviewThread` takes the same input and reopens it.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| `404` on `.../comments/{id}/replies` | The id is a review id or a conversation comment id, not an inline review comment | Only `kind: inline` items are replyable in a thread; the rest belong in the aggregated comment |
| `422 Unprocessable Entity` on a reply | The root comment was deleted, or the PR is locked | Re-run the fetch script; a comment that no longer exists is dropped from the triage |
| `Could not resolve to a node with the global id` | The `thread_id` is stale or from a different PR | Re-run the fetch script — thread ids change when a review is dismissed and re-created |
| Resolve fails with `Resource not accessible` | Only the PR author, a repo maintainer, or the thread's own author can resolve | Post the reply without `resolve`, and say so |
| Exit code 3 from `submit-replies.sh` | Replies post one call at a time; some landed | Delete the refs it lists from the replies file, then re-run. Never re-run the whole file |
| Everything 403s | The token lacks write access, or the PR is on a fork you cannot write to | Nothing can be posted; report it and hand the user the reply texts to paste |

## Things the scripts do not do

- **Edit a reply already posted**: `gh api --method PATCH repos/{r}/pulls/comments/{id} -f body='…'`
  (inline) or `gh api --method PATCH repos/{r}/issues/comments/{id} -f body='…'` (conversation).
- **Delete one**: `gh api --method DELETE repos/{r}/pulls/comments/{id}`. The deletion is silent
  but the reviewer's notification already went out.
- **Re-request a review after the fixes**:
  `gh api --method POST repos/{r}/pulls/{n}/requested_reviewers -f 'reviewers[]=login'`.
- **Read a thread in full** (the reviewer's follow-ups, not just the root):
  `gh api repos/{r}/pulls/{n}/comments --jq '[.[] | select(.id == ID or .in_reply_to_id == ID)]'`.
