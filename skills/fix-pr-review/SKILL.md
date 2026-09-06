---
name: fix-pr-review
description: Work through the review comments on a GitHub pull request — check every comment against the real code and the PRD or implementation plan the PR was built from, sort them into MUST APPLY / NICE TO HAVE / USELESS, fix the ones the user picks one at a time with a commit message per fix, then post a reply to every comment, fixed and skipped alike. Requires a PR carrying review comments and a PRD or implementation plan to check them against; refuses without both. Use when asked to "fix the PR review", "address the review comments", "apply the feedback on my PR", "answer the reviewer", "handle the comments on my PR", "respond to CodeRabbit/Copilot/the bot", or when invoked as /fix-pr-review. Answers a review; writing one is `pr-review`'s ground.
---

# Fix a PR Review

Turns a pile of review comments into landed fixes and answered threads. Two failures it exists
to prevent: applying a comment that is simply wrong about the code, and leaving a reviewer
waiting on threads nobody ever answered.

**Every comment gets a verdict, and every comment gets a reply** — including the ones the user
refuses to act on.

## Ground rules

- **No PR, or no plan, no run.** The comments come from a pull request; their veracity is judged
  against a PRD or implementation plan. Missing the PR, stop and say so. Missing the document,
  stop and offer `write-implementation-plan` — without a yardstick you can only guess whether a
  reviewer's demand was ever in scope.
- **Verify before you agree.** A comment is a claim about code. Read the code and the plan and
  cite what you found (`path:line`, or the requirement id) before assigning any category.
  Reviewers — bots especially — describe code that is not there.
- **The user decides what gets fixed; you decide nothing silently.** Never fix an unselected
  comment because it looked easy, and never drop a selected one because you disagree.
- **Never invent a reason for skipping.** The skip reply is the user's justification, condensed.
  No justification given means the reply says only that it is not being changed in this PR.
- **One comment per fix iteration.** Fix exactly what the comment asks, verify, hand over a
  commit message, stop. Bundling two comments into one diff makes both replies unverifiable.
- **You suggest the commit; the user commits.** Never run `git add`, `git commit`, `git push`, or
  `gh pr checkout` — the last one moves the user's branch.
- **Nothing is posted until the user has seen the exact text.** A reply notifies the reviewer and
  re-running posts a second one; there is no edit-in-place. Dry-run, show, confirm, then post.
- **Never claim a fix that is not pushed.** The reply says what landed on the branch the reviewer
  can see. Fixes still sitting in the working tree are not fixes yet.

## Workflow

- [ ] Step 1 — Resolve the PR and the document (hard gate)
- [ ] Step 2 — Collect every comment
- [ ] Step 3 — Verify each comment and categorize it
- [ ] Step 4 — Get the selection, then the reasons for the rest
- [ ] Step 5 — Fix, one comment per iteration
- [ ] Step 6 — Reply to every comment, then resolve what was fixed

Write `comments.json` and `replies.json` to the scratchpad directory, never into the repo.

---

### Step 1 — Resolve the PR and the document (hard gate)

Use the number or URL the user gave; with none, infer it from the branch:

```bash
gh pr view --json number,url,headRefOid,headRefName,baseRefName,author,body,state
```

No PR on the branch means there is nothing to answer — stop.

Then find what the PR is judged against, stopping at the first that exists:

1. A path the user named.
2. A PRD or implementation plan in the repo — search by content, not filename:
   ```bash
   rg -l --iglob '*.md' -e '^# PRD' -e 'Implementation Plan' -e 'Acceptance criteria'
   ```
   then check `docs/plans/`, `docs/`, and the repo root.
3. A plan or PRD linked from the PR body or from the issue it closes.

Read it before reading any comment. If none exists, **stop** and offer
`write-implementation-plan`. Do not substitute the issue: an issue states intent, not the
numbered requirements and non-goals that decide whether a reviewer's demand was ever in scope.

Confirm the checked-out branch is the PR's `headRefName` — step 5 fixes code in the working tree,
so anywhere else the commits land on the wrong branch. If it is not, stop and let the user switch;
do not switch for them.

Then read the PR's code without disturbing that branch:

```bash
git fetch origin pull/<n>/head:pr-<n>
git show pr-<n>:<path>          # the file as the reviewer saw it
gh pr diff <n>
```

### Step 2 — Collect every comment

```bash
scripts/fetch-pr-comments.sh --pr <n> > <scratch>/comments.json
```

It merges inline threads, review summary bodies and conversation comments into one array, drops
the noise GitHub generates (empty review bodies, resolved threads, your own comments), and
attaches the GraphQL `thread_id` each inline comment needs later. `--help` lists the flags;
`--exclude-bots` and `--include-resolved` are the two worth knowing.

A long review body often holds several distinct asks. Split it into one triage row per ask under
the parent ref (`C4a`, `C4b`) so each gets its own verdict — but they are triage rows, not reply
targets: step 6 folds them back into the single entry `C4`, since GitHub has one place to answer.

Report the count by author and kind, then continue. Zero comments means there is nothing to do:
say so and stop.

### Step 3 — Verify each comment and categorize it

For each comment, first establish **what is true**:

1. Read the code it points at, in the PR head (`git show pr-<n>:<path>`), not the working tree —
   the tree may already contain unrelated work.
2. An outdated comment (`"outdated": true`, `line` null) points at code that has moved. Its body
   quotes the hunk it was written against; find that code on the branch, or establish it is gone.
3. Check the plan: which numbered requirement, contract, or non-goal covers this?
4. For a bot comment, treat every factual claim as unverified until you have read the line.

Then one verdict, each backed by a citation:

| Verdict | Means |
| --- | --- |
| `TRUE` | The code does what the comment says, and the comment's concern holds |
| `TRUE, OUT OF SCOPE` | Accurate, but the plan puts it outside this change (a non-goal, or a later phase) |
| `STALE` | Was true when written; a later commit on the branch already fixed it |
| `FALSE` | The claim misreads the code — name the line that disproves it |

Category follows from the verdict plus impact, with effort as a tiebreak only:

- **MUST APPLY** — `TRUE`, and it breaks a plan requirement, a published contract, correctness,
  security, or data integrity. Effort never demotes this; a costly fix stays MUST APPLY with the
  cost stated.
- **NICE TO HAVE** — `TRUE` but the harm is cosmetic, stylistic, or a performance claim with no
  evidence behind it; or `TRUE, OUT OF SCOPE` with real value. Say what the fix costs, because
  that is what the user will weigh.
- **USELESS** — `FALSE`, `STALE`, or it contradicts an explicit decision or non-goal in the plan.
  Cite the line or the plan section that makes it so.

Present the triage as one table, in category order:

```
| Ref | Cat | Comment | Author | Location | Verdict | Why |
|-----|-----|---------|--------|----------|---------|-----|
| C3 | MUST APPLY | Retry re-charges on timeout | octocat | src/charge.ts:112 | TRUE | Breaks REQ-7 (idempotent charge); the retry wraps the whole call |
| C7 | NICE TO HAVE | Extract the parser | copilot[bot] | src/parse.ts:40 | TRUE, OUT OF SCOPE | Plan §Non-goals defers it to the second consumer; ~2h |
| C9 | USELESS | Missing null check on `user` | copilot[bot] | src/auth.ts:22 | FALSE | Line 19 already returns early when `user` is null |
```

### Step 4 — Get the selection, then the reasons for the rest

Ask which comments to fix (`AskUserQuestion`, multi-select, refs and titles). Recommend every
MUST APPLY and say so — but the selection is theirs, including a MUST APPLY they refuse.

Then ask, in one round, **why** each unselected comment is being skipped. That answer is the
reply the reviewer will read, so it has to come from the user, not from you.

Analyse each justification against what step 3 established, and act on the result:

- **Consistent with the evidence** — accept it, record it verbatim for step 6.
- **Contradicted by the evidence** ("it's already handled" when it is not) — push back **once**,
  showing the line. If the user reaffirms, that is their call: record their reason as given and
  move on.
- **A deferral** ("later PR", "another ticket") — ask which issue carries it. A deferral with a
  tracking reference is a strong reply; one without is an admission, and the reply must not
  dress it up as a plan.
- **None given** — do not fill the gap. The reply states the comment is not being changed in
  this PR, and nothing more.

Restate the final split — fixing, skipped with reason — and get a yes before touching code.

### Step 5 — Fix, one comment per iteration

Per selected comment, in order of category (MUST APPLY first):

1. **Fix exactly what the comment asks.** Not the surrounding code, not the same pattern
   elsewhere unless the comment says so. A fix that grows past the comment makes the reply a
   lie and the review a moving target.
2. **Verify.** Run the repo's own checks — format, lint, typecheck, existing tests — as the repo
   defines them, scoped to what the diff touched. Never guess a command from the ecosystem.
3. **Suggest the commit**, derived from the repo's history (`git log --oneline -30`):

   ```
   fix(<scope>): <what the comment asked for>
   ```

   One commit per comment, so each reply points at one change. Print it; do not commit.
4. **Record for the reply**: the files touched and one line on what changed.

Then stop and wait for the user before the next comment. If a fix turns out to need a change the
comment never asked for (a contract change, a migration, a second file's behavior), stop and ask
— that is a plan decision, not a review fix.

If a fix cannot be made, say so plainly and move that comment to skipped, with the blocker as its
reason — never leave it silently unfixed and reply as if it landed.

### Step 6 — Reply to every comment, then resolve what was fixed

First check the fixes are visible to the reviewer:

```bash
git status --short                       # must be clean of the fix files
git log --oneline origin/<branch>..HEAD  # must be empty
```

Anything uncommitted or unpushed, stop and tell the user what to push. A reply claiming a fix the
reviewer cannot see is worse than no reply.

Build `<scratch>/replies.json` — **one entry per comment collected in step 2**, fixed and skipped
alike (a comment split into `C4a`/`C4b` gets one entry, `C4`, covering both), in the shape
`scripts/submit-replies.sh --help` documents. Bodies are 1–3 sentences, plain statements of fact:

```
Fixed  →  "Fixed in `src/charge.ts`: the retry now wraps the response read instead of the
           whole call, so a gateway timeout no longer re-charges."
Skipped →  "Not changing this here — the plan scopes the parser to this package until a second
           consumer exists (tracked in #482)."
```

No "great catch", no apology, no restating the comment back, no SHA you have not confirmed
exists. A skipped reply is the user's reason condensed — nothing added.

Set `"resolve": true` only on threads whose fix landed, and only after asking the user whether to
resolve them. Skipped threads stay open so the reviewer can push back.

Then validate, show, and post:

```bash
scripts/submit-replies.sh --pr <n> --replies-file <scratch>/replies.json --dry-run
```

Fix what it rejects and re-run until it prints `OK:`. Show the user every reply body as it will
appear, get an explicit go-ahead, then:

```bash
scripts/submit-replies.sh --pr <n> --replies-file <scratch>/replies.json --confirm
```

On exit code 3 some replies posted — delete those refs from the file before re-running, or the
reviewer gets them twice. Read `references/github-comment-api.md` for any other failure, or when
you need to edit or delete something already posted.

Close with: how many comments were fixed, skipped and why, the commit messages suggested, the
threads resolved, and anything still open (a deferral with no issue, a MUST APPLY the user
declined). Offer a re-review; do not run one unasked.

## Gotchas

- **`line` is `null` on an outdated comment**, and no current line exists for it. Use the
  `diff_hunk` in the body plus `original_line` to find the code; never invent a line number.
- **A bot's login changes between endpoints** — Copilot is `Copilot`, `copilot-…[bot]`, or
  `copilot-…` depending on which API answered. Filter on the `is_bot` field, never on a login.
- **Only the root comment of a thread accepts a reply.** Replying to a reply's id fails; the
  fetch script returns roots only and `submit-replies.sh` names the root when you get it wrong.
- **Thread ids exist only in GraphQL.** REST never returns the `PRRT_…` id that resolving needs,
  which is why the fetch script joins the two.
- **Replies are not atomic.** Unlike submitting a review, each reply is its own call — a failure
  halfway leaves the earlier ones posted. That is exit code 3, and re-running the whole file
  double-posts.
- **GitHub creates an empty review every time someone replies in a thread.** Those are not
  feedback; if you ever bypass the fetch script, filter `body != ""` yourself.
- **A resolved thread is a closed conversation.** The fetch script drops them by default;
  re-opening one with a reply is noise unless the user asks for it.
- **A comment can be right about the code and still be `USELESS` here** — the plan's non-goals
  decide scope, not the reviewer. Say which section, so the reply has something to stand on.
- **`pr-review` and this skill both mention "PR" and "review".** That one publishes findings onto
  someone's PR; this one answers findings left on yours. If the user wants to *review* code,
  stop and hand off.
