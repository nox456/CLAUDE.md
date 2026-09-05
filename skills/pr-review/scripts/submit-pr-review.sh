#!/usr/bin/env bash
# Submit ONE GitHub pull request review: a summary body plus inline comments, validated
# against the PR diff first so a bad line number cannot reject the whole review.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: submit-pr-review.sh --pr N --body-file FILE --comments-file FILE
                          [--repo OWNER/NAME] [--event EVENT] (--dry-run | --confirm)

Validates every inline comment against the PR diff, then posts a single review via
POST /repos/{owner}/{repo}/pulls/{n}/reviews. GitHub rejects a review atomically: one
comment on a line outside the diff loses all of them, which is what --dry-run prevents.

Options:
  --pr N             Pull request number. Required.
  --body-file FILE   Markdown file for the review's summary comment. Required.
  --comments-file FILE
                     JSON array of inline comments. Required (use [] for none). Each item:
                       {"path": "src/a.ts", "line": 88, "body": "...",
                        "side": "RIGHT", "start_line": 80, "start_side": "RIGHT"}
                     path is repo-relative; line is a line number in the file at the PR head
                     (side RIGHT) or base (side LEFT); side defaults to RIGHT; start_line is
                     optional and makes the comment span start_line..line.
  --repo OWNER/NAME  Defaults to the repo of the current directory.
  --event EVENT      REQUEST_CHANGES (default), COMMENT, or APPROVE.
  --dry-run          Validate and print the payload summary; post nothing.
  --confirm          Actually post the review. Required to publish: with neither flag the
                     script exits 2 without contacting GitHub. Re-running posts a SECOND
                     review — a submitted review cannot be deleted, only dismissed.
  -h, --help         Show this help.

Exit codes:
  0  Review posted, or --dry-run validated clean.
  1  Validation failed, or the API call failed.
  2  Usage error, including neither --dry-run nor --confirm.
  3  GitHub refused the event (e.g. REQUEST_CHANGES on your own PR) — retry with
     --event COMMENT.

Example:
  scripts/submit-pr-review.sh --pr 412 --body-file review.md --comments-file comments.json --dry-run
  scripts/submit-pr-review.sh --pr 412 --body-file review.md --comments-file comments.json --confirm
USAGE
}

die() { echo "Error: $1" >&2; exit "${2:-1}"; }

PR="" REPO="" BODY_FILE="" COMMENTS_FILE="" EVENT="REQUEST_CHANGES" DRY=0 CONFIRM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift ;;
    --repo) REPO="${2:-}"; shift ;;
    --body-file) BODY_FILE="${2:-}"; shift ;;
    --comments-file) COMMENTS_FILE="${2:-}"; shift ;;
    --event) EVENT="${2:-}"; shift ;;
    --dry-run) DRY=1 ;;
    --confirm) CONFIRM=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument \"$1\". Run --help for usage." >&2; exit 2 ;;
  esac
  shift
done

[ -n "$PR" ] || { echo "Error: --pr is required. Run --help for usage." >&2; exit 2; }
[ -n "$BODY_FILE" ] || { echo "Error: --body-file is required. Run --help for usage." >&2; exit 2; }
[ -n "$COMMENTS_FILE" ] || { echo "Error: --comments-file is required. Run --help for usage." >&2; exit 2; }
[ -f "$BODY_FILE" ] || die "--body-file not found: $BODY_FILE" 2
[ -f "$COMMENTS_FILE" ] || die "--comments-file not found: $COMMENTS_FILE" 2
if [ "$DRY" -eq 0 ] && [ "$CONFIRM" -eq 0 ]; then
  echo "Error: posting a review needs --confirm. Run with --dry-run first to validate it, then re-run with --confirm once the user has approved the exact body and comments." >&2
  exit 2
fi
case "$EVENT" in
  REQUEST_CHANGES|COMMENT|APPROVE) ;;
  *) echo "Error: --event must be one of REQUEST_CHANGES, COMMENT, APPROVE. Received: \"$EVENT\"" >&2; exit 2 ;;
esac
command -v gh >/dev/null || die "gh is not installed."
command -v jq >/dev/null || die "jq is not installed."

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
    || die "could not infer the repo. Pass --repo OWNER/NAME." 2
fi

jq -e 'type == "array"' "$COMMENTS_FILE" >/dev/null 2>&1 \
  || die "--comments-file must contain a JSON array. Received: $(head -c 60 "$COMMENTS_FILE")"
jq -e 'all(.[]; has("path") and has("line") and has("body"))' "$COMMENTS_FILE" >/dev/null 2>&1 \
  || die "every comment needs \"path\", \"line\" and \"body\"."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh pr diff "$PR" --repo "$REPO" > "$TMP/diff" 2>"$TMP/err" \
  || die "gh pr diff failed for $REPO#$PR: $(cat "$TMP/err")"
[ -s "$TMP/diff" ] || die "$REPO#$PR has an empty diff — nothing to comment on."

# Lines that GitHub will accept a comment on: every added and context line of the diff,
# numbered in the file at the head ref (RIGHT), and removed/context lines for LEFT.
awk '
  /^\+\+\+ / { f = substr($0, 5); sub(/^b\//, "", f); if (f == "/dev/null") f = ""; next }
  /^--- /    { next }
  /^@@ /     {
      inhunk = (f != "")
      if (match($0, /-[0-9]+/)) { old = substr($0, RSTART + 1, RLENGTH - 1) + 0 }
      if (match($0, /\+[0-9]+/)) { new = substr($0, RSTART + 1, RLENGTH - 1) + 0 }
      next
  }
  !inhunk { next }
  /^\\/    { next }
  {
      c = substr($0, 1, 1)
      if (c == "+")      { print f "\tRIGHT\t" new; new++ }
      else if (c == "-") { print f "\tLEFT\t"  old; old++ }
      else if (c == " " || $0 == "") { print f "\tRIGHT\t" new; print f "\tLEFT\t" old; new++; old++ }
      else               { inhunk = 0 }
  }
' "$TMP/diff" | sort -u > "$TMP/valid"

fail=0
n="$(jq length "$COMMENTS_FILE")"
i=0
while [ "$i" -lt "$n" ]; do
  path="$(jq -r ".[$i].path" "$COMMENTS_FILE")"
  line="$(jq -r ".[$i].line" "$COMMENTS_FILE")"
  side="$(jq -r ".[$i].side // \"RIGHT\"" "$COMMENTS_FILE")"
  start="$(jq -r ".[$i].start_line // empty" "$COMMENTS_FILE")"
  i=$((i + 1))

  if ! grep -qP "^\Q$path\E\t" "$TMP/valid"; then
    echo "Error: comment $i — \"$path\" is not in the diff of $REPO#$PR. Move this finding into the summary body." >&2
    fail=1
    continue
  fi
  check_line() { # line, label
    if ! grep -qxP "\Q$path\E\t$side\t$1" "$TMP/valid"; then
      near="$(grep -P "^\Q$path\E\t$side\t" "$TMP/valid" | cut -f3 | sort -n | awk -v t="$1" '
        { d = ($1 > t ? $1 - t : t - $1); if (d < bd || NR == 1) { bd = d; b = $1 } } END { print b }')"
      echo "Error: comment $i — $path:$1 ($2, side $side) is not part of the diff. Nearest commentable line on that side: $near. Retarget or move the finding into the summary body." >&2
      fail=1
    fi
  }
  check_line "$line" "line"
  if [ -n "$start" ]; then
    check_line "$start" "start_line"
    [ "$start" -lt "$line" ] || { echo "Error: comment $i — start_line ($start) must be less than line ($line) in $path." >&2; fail=1; }
  fi
done
[ "$fail" -eq 0 ] || die "$(( $(jq length "$COMMENTS_FILE") )) comment(s) checked, validation failed. Nothing was posted."

SHA="$(gh pr view "$PR" --repo "$REPO" --json headRefOid -q .headRefOid 2>/dev/null)" \
  || die "could not read the head SHA of $REPO#$PR."

jq -n \
  --arg commit_id "$SHA" \
  --arg event "$EVENT" \
  --rawfile body "$BODY_FILE" \
  --slurpfile comments "$COMMENTS_FILE" \
  '{commit_id: $commit_id, event: $event, body: $body,
    comments: ($comments[0] | map({path, line, body, side: (.side // "RIGHT")}
                                  + (if .start_line then {start_line, start_side: (.start_side // .side // "RIGHT")} else {} end)))}' \
  > "$TMP/payload.json" || die "could not build the review payload."

if [ "$DRY" -eq 1 ]; then
  jq '{repo: "'"$REPO"'", pr: '"$PR"', commit_id, event, inline_comments: (.comments | length),
       comments: (.comments | map({path, side, lines: (if .start_line then "\(.start_line)-\(.line)" else "\(.line)" end)}))}' "$TMP/payload.json"
  echo "OK: payload valid. Re-run with --confirm to post it." >&2
  exit 0
fi

if ! gh api --method POST "repos/$REPO/pulls/$PR/reviews" --input "$TMP/payload.json" > "$TMP/out" 2>"$TMP/err"; then
  if grep -qi "own pull request" "$TMP/err"; then
    echo "Error: GitHub refuses $EVENT on your own pull request. Re-run with --event COMMENT." >&2
    exit 3
  fi
  die "the review was rejected by GitHub and nothing was posted: $(cat "$TMP/err")"
fi

jq -r '{url: .html_url, state: .state, inline_comments: '"$(jq length "$COMMENTS_FILE")"'}' "$TMP/out"
