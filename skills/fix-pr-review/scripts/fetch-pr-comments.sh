#!/usr/bin/env bash
# Collect every reviewer comment on a pull request — inline threads, review summary bodies and
# conversation comments — into one normalized JSON array, with the GraphQL thread id each
# inline comment needs before it can be replied to or resolved.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: fetch-pr-comments.sh --pr N [--repo OWNER/NAME] [--exclude-bots] [--include-resolved]
                            [--include-own] [--max-body N]

Reads three GitHub sources and merges them into a single JSON array on stdout, one object per
comment worth triaging:

  inline        root review comments (replies inside a thread are folded into reply_count)
  review        review summary bodies, skipping the empty ones GitHub creates to carry a reply
  conversation  top-level PR comments

Each item:
  {"ref":"C1","kind":"inline","author":"octocat","is_bot":false,
   "path":"src/charge.ts","line":112,"outdated":false,
   "thread_id":"PRRT_kwDO...","comment_id":3912327435,"resolved":false,
   "reply_count":1,"last_reply_author":"octocat","url":"https://github.com/...",
   "body":"..."}

thread_id is present for inline items only; it is what submit-replies.sh resolves. line is null
when the comment is outdated — path plus the body's own quoted hunk is then the only location.

Options:
  --pr N              Pull request number. Required.
  --repo OWNER/NAME   Defaults to the repo of the current directory.
  --exclude-bots      Drop items whose author is a GitHub App (user.type == "Bot").
  --include-resolved  Keep inline threads already marked resolved (dropped by default).
  --include-own       Keep comments written by the authenticated user (dropped by default).
  --max-body N        Truncate each body to N characters, appending a pointer to the URL.
                      Default 4000. Use 0 for no limit.
  -h, --help          Show this help.

Exit codes:
  0  Array printed (possibly empty).
  1  A GitHub call failed.
  2  Usage error.

Example:
  scripts/fetch-pr-comments.sh --pr 412 > comments.json
  jq -r '.[] | "\(.ref) \(.kind) \(.author) \(.path // "-"):\(.line // "-")"' comments.json
USAGE
}

die() { echo "Error: $1" >&2; exit "${2:-1}"; }

PR="" REPO="" EXCLUDE_BOTS=0 INCLUDE_RESOLVED=0 INCLUDE_OWN=0 MAX_BODY=4000
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift ;;
    --repo) REPO="${2:-}"; shift ;;
    --exclude-bots) EXCLUDE_BOTS=1 ;;
    --include-resolved) INCLUDE_RESOLVED=1 ;;
    --include-own) INCLUDE_OWN=1 ;;
    --max-body) MAX_BODY="${2:-}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument \"$1\". Run --help for usage." >&2; exit 2 ;;
  esac
  shift
done

[ -n "$PR" ] || { echo "Error: --pr is required. Run --help for usage." >&2; exit 2; }
case "$PR" in ''|*[!0-9]*) echo "Error: --pr must be a number. Received: \"$PR\"" >&2; exit 2 ;; esac
case "$MAX_BODY" in ''|*[!0-9]*) echo "Error: --max-body must be a non-negative number. Received: \"$MAX_BODY\"" >&2; exit 2 ;; esac
command -v gh >/dev/null || die "gh is not installed."
command -v jq >/dev/null || die "jq is not installed."

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
    || die "could not infer the repo. Pass --repo OWNER/NAME." 2
fi
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
[ -n "$OWNER" ] && [ -n "$NAME" ] && [ "$OWNER" != "$REPO" ] \
  || die "--repo must look like OWNER/NAME. Received: \"$REPO\"" 2

ME="$(gh api user -q .login 2>/dev/null)" || die "could not read the authenticated user."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh api --paginate "repos/$REPO/pulls/$PR/comments" > "$TMP/inline.json" 2>"$TMP/err" \
  || die "could not list review comments for $REPO#$PR: $(cat "$TMP/err")"
gh api --paginate "repos/$REPO/pulls/$PR/reviews" > "$TMP/reviews.json" 2>"$TMP/err" \
  || die "could not list reviews for $REPO#$PR: $(cat "$TMP/err")"
gh api --paginate "repos/$REPO/issues/$PR/comments" > "$TMP/conv.json" 2>"$TMP/err" \
  || die "could not list conversation comments for $REPO#$PR: $(cat "$TMP/err")"

# gh --paginate emits one JSON array per page; slurp them into a single flat array.
for f in inline reviews conv; do
  jq -s 'add // []' "$TMP/$f.json" > "$TMP/$f.flat.json" \
    || die "could not parse the $f response."
  mv "$TMP/$f.flat.json" "$TMP/$f.json"
done

# Thread ids and resolution state live only in GraphQL. Join them to REST by the database id
# of the thread's first comment.
gh api graphql --paginate \
  -f query='query($owner:String!,$name:String!,$pr:Int!,$endCursor:String){
    repository(owner:$owner,name:$name){
      pullRequest(number:$pr){
        reviewThreads(first:100, after:$endCursor){
          pageInfo{ hasNextPage endCursor }
          nodes{ id isResolved comments(first:1){ nodes{ databaseId } } }
        }
      }
    }
  }' -f owner="$OWNER" -f name="$NAME" -F pr="$PR" \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | {root: (.comments.nodes[0].databaseId // 0), id, resolved: .isResolved}' \
  > "$TMP/threads.ndjson" 2>"$TMP/err" \
  || die "could not read review threads for $REPO#$PR: $(cat "$TMP/err")"
jq -s 'map({key: (.root|tostring), value: {id, resolved}}) | from_entries' \
  "$TMP/threads.ndjson" > "$TMP/threads.json" || die "could not index the review threads."

jq -n \
  --argjson inline "$(cat "$TMP/inline.json")" \
  --argjson reviews "$(cat "$TMP/reviews.json")" \
  --argjson conv "$(cat "$TMP/conv.json")" \
  --argjson threads "$(cat "$TMP/threads.json")" \
  --arg me "$ME" \
  --argjson exclude_bots "$EXCLUDE_BOTS" \
  --argjson include_resolved "$INCLUDE_RESOLVED" \
  --argjson include_own "$INCLUDE_OWN" \
  --argjson max_body "$MAX_BODY" '
  def clip($url):
    if $max_body > 0 and (. | length) > $max_body
    then (.[0:$max_body] + "\n\n…[truncated — full text: " + $url + "]")
    else . end;

  ($inline | map(select(.in_reply_to_id != null))) as $replies |

  ( $inline
    | map(select(.in_reply_to_id == null))
    | map(. as $c
        | ($threads[($c.id|tostring)] // {id: null, resolved: false}) as $t
        | ($replies | map(select(.in_reply_to_id == $c.id))) as $r
        | {kind: "inline",
           author: $c.user.login,
           is_bot: ($c.user.type == "Bot"),
           path: $c.path,
           line: $c.line,
           outdated: ($c.line == null),
           thread_id: $t.id,
           comment_id: $c.id,
           resolved: $t.resolved,
           reply_count: ($r | length),
           last_reply_author: ($r | last | .user.login? // null),
           created_at: $c.created_at,
           url: $c.html_url,
           body: ($c.body // "")}) ) as $a |

  ( $reviews
    | map(select((.body // "") != "" and .state != "PENDING"))
    | map({kind: "review",
           author: .user.login,
           is_bot: (.user.type == "Bot"),
           path: null, line: null, outdated: false,
           thread_id: null,
           comment_id: .id,
           resolved: false,
           reply_count: 0,
           last_reply_author: null,
           created_at: .submitted_at,
           url: .html_url,
           body: (.body // "")}) ) as $b |

  ( $conv
    | map({kind: "conversation",
           author: .user.login,
           is_bot: (.user.type == "Bot"),
           path: null, line: null, outdated: false,
           thread_id: null,
           comment_id: .id,
           resolved: false,
           reply_count: 0,
           last_reply_author: null,
           created_at: .created_at,
           url: .html_url,
           body: (.body // "")}) ) as $d |

  ($a + $b + $d)
  | map(select($include_own == 1 or .author != $me))
  | map(select($exclude_bots == 0 or .is_bot == false))
  | map(select($include_resolved == 1 or .resolved == false))
  | sort_by(.created_at)
  | to_entries
  | map(. as $e
        | $e.value + {ref: ("C" + (($e.key + 1) | tostring)),
                      body: ($e.value.body | clip($e.value.url))})
  | map({ref, kind, author, is_bot, path, line, outdated, thread_id, comment_id,
         resolved, reply_count, last_reply_author, url, body})
  ' || die "could not build the comment list."
