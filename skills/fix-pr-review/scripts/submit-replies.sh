#!/usr/bin/env bash
# Post one reply per review comment on a pull request: a threaded reply for every inline
# comment, one aggregated conversation comment for the feedback GitHub gives no thread to
# (review summary bodies and top-level comments), then resolve the threads flagged for it.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: submit-replies.sh --pr N --replies-file FILE [--repo OWNER/NAME] (--dry-run | --confirm)

Validates every reply against the PR's real comments, then posts them. Inline replies land in
their own thread; review-body and conversation replies are batched into ONE conversation
comment so the reviewer gets a single notification instead of one per item.

--replies-file is a JSON array. One object per comment, covering EVERY comment triaged —
fixed and skipped alike:

  [
    {"ref":"C1","kind":"inline","comment_id":3912327435,
     "thread_id":"PRRT_kwDO...","resolve":true,
     "body":"Fixed: the retry now wraps the response read only, so a gateway timeout no longer re-charges."},
    {"ref":"C4","kind":"review","author":"octocat","url":"https://github.com/o/r/pull/9#pullrequestreview-1",
     "quote":"Consider extracting the parser into its own package",
     "body":"Skipping: the plan scopes the parser to this package until the second consumer exists."}
  ]

  ref         Identifier from fetch-pr-comments.sh. Must be unique.
  kind        inline | review | conversation.
  comment_id  Required. For inline, the ROOT comment of the thread (in_reply_to_id null).
  thread_id   GraphQL thread id. Required only when resolve is true.
  resolve     Optional, inline only, default false. Resolves the thread after the reply posts.
  body        The reply, 1-3 sentences. Required, non-empty.
  author/quote/url
              Used to head each entry in the aggregated comment. review/conversation only.

Options:
  --pr N              Pull request number. Required.
  --replies-file FILE JSON array as above. Required.
  --repo OWNER/NAME   Defaults to the repo of the current directory.
  --dry-run           Validate and print exactly what would be posted. Posts nothing.
  --confirm           Post. Required to publish: with neither flag the script exits 2 without
                      contacting GitHub. Replies are NOT atomic — see exit code 3.
  -h, --help          Show this help.

Exit codes:
  0  Everything posted, or --dry-run validated clean.
  1  Validation failed and nothing was posted, or every call failed.
  2  Usage error, including neither --dry-run nor --confirm.
  3  Partially posted. The refs that succeeded are listed on stderr — delete them from the
     replies file before re-running, or they will be posted twice.

Example:
  scripts/submit-replies.sh --pr 412 --replies-file replies.json --dry-run
  scripts/submit-replies.sh --pr 412 --replies-file replies.json --confirm
USAGE
}

die() { echo "Error: $1" >&2; exit "${2:-1}"; }

PR="" REPO="" FILE="" DRY=0 CONFIRM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift ;;
    --repo) REPO="${2:-}"; shift ;;
    --replies-file) FILE="${2:-}"; shift ;;
    --dry-run) DRY=1 ;;
    --confirm) CONFIRM=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument \"$1\". Run --help for usage." >&2; exit 2 ;;
  esac
  shift
done

[ -n "$PR" ] || { echo "Error: --pr is required. Run --help for usage." >&2; exit 2; }
[ -n "$FILE" ] || { echo "Error: --replies-file is required. Run --help for usage." >&2; exit 2; }
[ -f "$FILE" ] || die "--replies-file not found: $FILE" 2
if [ "$DRY" -eq 0 ] && [ "$CONFIRM" -eq 0 ]; then
  echo "Error: posting replies needs --confirm. Run with --dry-run first, show the user every reply, and re-run with --confirm once they approve." >&2
  exit 2
fi
command -v gh >/dev/null || die "gh is not installed."
command -v jq >/dev/null || die "jq is not installed."

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
    || die "could not infer the repo. Pass --repo OWNER/NAME." 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

jq -e 'type == "array" and length > 0' "$FILE" >/dev/null 2>&1 \
  || die "--replies-file must contain a non-empty JSON array. Received: $(head -c 60 "$FILE")"

# --- validation -------------------------------------------------------------------------
gh api --paginate "repos/$REPO/pulls/$PR/comments" 2>"$TMP/err" | jq -s 'add // []' > "$TMP/inline.json" \
  || die "could not list review comments for $REPO#$PR: $(cat "$TMP/err")"

fail=0
n="$(jq length "$FILE")"
i=0
while [ "$i" -lt "$n" ]; do
  ref="$(jq -r ".[$i].ref // empty" "$FILE")"
  kind="$(jq -r ".[$i].kind // empty" "$FILE")"
  cid="$(jq -r ".[$i].comment_id // empty" "$FILE")"
  tid="$(jq -r ".[$i].thread_id // empty" "$FILE")"
  resolve="$(jq -r ".[$i].resolve // false" "$FILE")"
  body="$(jq -r ".[$i].body // empty" "$FILE")"
  label="entry $((i + 1))${ref:+ ($ref)}"
  i=$((i + 1))

  [ -n "$ref" ]  || { echo "Error: $label — \"ref\" is required." >&2; fail=1; }
  [ -n "$body" ] || { echo "Error: $label — \"body\" is required and must be non-empty." >&2; fail=1; }
  [ -n "$cid" ]  || { echo "Error: $label — \"comment_id\" is required." >&2; fail=1; }
  case "$kind" in
    inline|review|conversation) ;;
    *) echo "Error: $label — \"kind\" must be inline, review or conversation. Received: \"$kind\"" >&2; fail=1 ;;
  esac
  if [ "${#body}" -gt 600 ]; then
    echo "Warning: $label — the reply is ${#body} characters. Replies are meant to be 1-3 sentences." >&2
  fi
  if [ "$kind" = "inline" ] && [ -n "$cid" ]; then
    if ! jq -e --argjson id "$cid" 'any(.[]; .id == $id and .in_reply_to_id == null)' "$TMP/inline.json" >/dev/null; then
      if jq -e --argjson id "$cid" 'any(.[]; .id == $id)' "$TMP/inline.json" >/dev/null; then
        root="$(jq -r --argjson id "$cid" '.[] | select(.id == $id) | .in_reply_to_id' "$TMP/inline.json")"
        echo "Error: $label — comment_id $cid is a reply, not the root of its thread. Use $root." >&2
      else
        echo "Error: $label — comment_id $cid is not a review comment on $REPO#$PR." >&2
      fi
      fail=1
    fi
  fi
  if [ "$resolve" = "true" ]; then
    [ "$kind" = "inline" ] || { echo "Error: $label — only inline comments have a thread to resolve." >&2; fail=1; }
    [ -n "$tid" ] || { echo "Error: $label — \"resolve\": true needs \"thread_id\" (the PRRT_… id from fetch-pr-comments.sh)." >&2; fail=1; }
  fi
done

dupes="$(jq -r '[.[].ref] | group_by(.) | map(select(length > 1) | .[0]) | join(", ")' "$FILE")"
[ -z "$dupes" ] || { echo "Error: duplicate ref(s): $dupes. Each comment gets exactly one reply." >&2; fail=1; }

[ "$fail" -eq 0 ] || die "validation failed. Nothing was posted."

# --- aggregated comment for the kinds GitHub gives no thread ------------------------------
jq -r '
  map(select(.kind != "inline"))
  | if length == 0 then empty else
      "### Replies to review feedback\n\n" +
      ( map("**@" + (.author // "reviewer") + "**"
            + (if .url then " on [this comment](" + .url + ")" else "" end) + ":\n"
            + (if .quote then "\n> " + (.quote | gsub("\n"; "\n> ")) + "\n" else "" end)
            + "\n" + .body)
        | join("\n\n---\n\n") )
    end' "$FILE" > "$TMP/aggregate.md" || die "could not build the aggregated comment."

inline_n="$(jq '[.[] | select(.kind == "inline")] | length' "$FILE")"
other_n="$(jq '[.[] | select(.kind != "inline")] | length' "$FILE")"
resolve_n="$(jq '[.[] | select(.resolve == true)] | length' "$FILE")"

if [ "$DRY" -eq 1 ]; then
  jq -r '.[] | select(.kind == "inline")
         | "REPLY\t\(.ref)\tcomment \(.comment_id)\tresolve=\(.resolve // false)\n\(.body)\n"' "$FILE"
  if [ -s "$TMP/aggregate.md" ]; then
    echo "AGGREGATED CONVERSATION COMMENT ($other_n item(s)):"
    cat "$TMP/aggregate.md"
    echo
  fi
  echo "OK: $inline_n threaded repl(ies), $other_n item(s) in 1 conversation comment, $resolve_n thread(s) to resolve. Re-run with --confirm to post." >&2
  exit 0
fi

# --- post -------------------------------------------------------------------------------
posted="" failed=0 ok=0
i=0
while [ "$i" -lt "$n" ]; do
  idx="$i"
  i=$((i + 1))
  kind="$(jq -r ".[$idx].kind" "$FILE")"
  [ "$kind" = "inline" ] || continue
  ref="$(jq -r ".[$idx].ref" "$FILE")"
  cid="$(jq -r ".[$idx].comment_id" "$FILE")"
  tid="$(jq -r ".[$idx].thread_id // empty" "$FILE")"
  resolve="$(jq -r ".[$idx].resolve // false" "$FILE")"

  jq "{body: .[$idx].body}" "$FILE" > "$TMP/payload.json" || die "could not build the reply payload for $ref."
  if gh api --method POST "repos/$REPO/pulls/$PR/comments/$cid/replies" \
       --input "$TMP/payload.json" > "$TMP/out.json" 2>"$TMP/err"; then
    printf '%s\treplied\t%s\n' "$ref" "$(jq -r .html_url "$TMP/out.json")"
    posted="$posted $ref"; ok=$((ok + 1))
    if [ "$resolve" = "true" ]; then
      if gh api graphql -f query='mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' \
           -f id="$tid" >/dev/null 2>"$TMP/err"; then
        printf '%s\tresolved\t%s\n' "$ref" "$tid"
      else
        echo "Warning: $ref — the reply posted but the thread was not resolved: $(head -c 200 "$TMP/err")" >&2
      fi
    fi
  else
    echo "Error: $ref — reply failed: $(head -c 300 "$TMP/err")" >&2
    failed=$((failed + 1))
  fi
done

aggregate_posted=0
if [ -s "$TMP/aggregate.md" ]; then
  if gh pr comment "$PR" --repo "$REPO" --body-file "$TMP/aggregate.md" > "$TMP/out.txt" 2>"$TMP/err"; then
    printf 'aggregate\tcommented\t%s\n' "$(cat "$TMP/out.txt")"
    aggregate_posted=1; ok=$((ok + 1))
  else
    echo "Error: the aggregated conversation comment failed: $(head -c 300 "$TMP/err")" >&2
    failed=$((failed + 1))
  fi
fi

if [ "$failed" -gt 0 ]; then
  if [ "$ok" -gt 0 ]; then
    [ "$aggregate_posted" -eq 1 ] && posted="$posted (aggregate)"
    echo "Error: $failed of $((ok + failed)) post(s) failed. Already posted:$posted. Remove those from the replies file before re-running, or they will be posted twice." >&2
    exit 3
  fi
  die "every post failed. Nothing reached $REPO#$PR."
fi
echo "OK: $inline_n threaded repl(ies), $other_n item(s) in 1 conversation comment, $resolve_n thread(s) resolved." >&2
