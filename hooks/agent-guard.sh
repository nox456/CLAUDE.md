#!/usr/bin/env bash
# PreToolUse guard for the subagents in agents/: turns their "report only", "never commit" and
# "never touch that kind of file" rules from instructions into denials.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: agent-guard.sh MODE < pretooluse.json

A Claude Code PreToolUse hook. Reads the hook input JSON on stdin, then allows the tool call
(exit 0) or denies it (exit 2, reason on stderr, which Claude Code hands back to the agent).

Modes:
  readonly    Bash runs only: git diff|log|show|status|rev-parse|fetch, rg, ls, cat,
              gh pr diff, gh pr view, gh issue view. No redirection into files, no command
              substitution. Used by code-reviewer and refactor-reviewer.
  no-git      Bash never runs git add|commit|push|stash|restore|reset|checkout|switch|rebase|
              merge|clean. Used by every agent.
  tests-only  Edit/Write only on a test file (fixtures and factories included) or *.md.
              Used by tester.
  src-only    Edit/Write never on a test file, fixture, factory or config. Used by
              mutation-tester.

A mode lets through the tools it does not guard. Anything the guard cannot read is denied:
a guard that fails open guards nothing. Exit 1 is never used, because Claude Code treats it
as a non-blocking error and runs the tool anyway.

Example (agent frontmatter):
  hooks:
    PreToolUse:
      - matcher: Bash
        hooks:
          - type: command
            command: "$HOME/.claude/hooks/agent-guard.sh no-git"
USAGE
}

MODE="${1:-}"

deny() { echo "agent-guard ${MODE:-?}: $1" >&2; exit 2; }

READONLY_ALLOWLIST='git diff|log|show|status|rev-parse|fetch, rg, ls, cat, gh pr diff, gh pr view, gh issue view'
NO_GIT_SUBCOMMANDS='add|commit|push|stash|restore|reset|checkout|switch|rebase|merge|clean'

# Replace every quoted string and escaped character with Q, so shell operators inside an
# argument ("a; b", '%an <%ae>') are not read as shell syntax. Fails on an unclosed quote.
unquote() {
  local s="$1" out="" quote="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    if [ -n "$quote" ]; then
      if [ "$quote" = '"' ] && [ "$c" = '\' ]; then
        i=$((i + 1))
      elif [ "$c" = "$quote" ]; then
        quote=""
      fi
      continue
    fi
    case "$c" in
      "'" | '"') quote="$c"; out+="Q" ;;
      '\') out+="Q"; i=$((i + 1)) ;;
      *) out+="$c" ;;
    esac
  done
  [ -z "$quote" ] || return 1
  printf '%s' "$out"
}

# Allow one simple command (no operators) against the read-only allowlist, or deny it.
check_readonly_segment() {
  local -a words
  read -ra words <<<"$1"
  [ "${#words[@]}" -gt 0 ] || return 0

  local word
  for word in "${words[@]}"; do
    case "$word" in
      --output | --output=* | --upload-pack* | --exec=*)
        deny "\"$word\" makes git write a file or run a program. Reviewers report; they do not change anything." ;;
    esac
  done

  case "${words[0]}" in
    ls | cat) return 0 ;;
    rg)
      for word in "${words[@]}"; do
        case "$word" in
          --pre | --pre=*) deny "rg --pre runs a program on every file. Search without it." ;;
        esac
      done
      return 0
      ;;
    gh)
      case "${words[1]:-} ${words[2]:-}" in
        "pr diff" | "pr view" | "issue view") return 0 ;;
      esac
      deny "\"gh ${words[1]:-} ${words[2]:-}\" is not on the read-only allowlist ($READONLY_ALLOWLIST)."
      ;;
    git)
      local i=1
      while [ "$i" -lt "${#words[@]}" ]; do
        case "${words[i]}" in
          -C) i=$((i + 2)) ;;
          --no-pager | -P) i=$((i + 1)) ;;
          -*) deny "git option \"${words[i]}\" is not allowed in read-only mode. Use git -C <dir> to target a worktree." ;;
          *) break ;;
        esac
      done
      case "${words[i]:-}" in
        diff | log | show | status | rev-parse | fetch) return 0 ;;
      esac
      deny "\"git ${words[i]:-}\" is not on the read-only allowlist ($READONLY_ALLOWLIST)."
      ;;
  esac
  deny "\"${words[0]}\" is not on the read-only allowlist ($READONLY_ALLOWLIST). Use the Read, Grep and Glob tools for anything else."
}

guard_readonly() {
  local raw="$1" cmd segment
  case "$raw" in
    *'`'* | *'$('* | *'<('* | *'>('*)
      deny "command substitution is not allowed in read-only mode. Run each command on its own." ;;
  esac
  cmd="$(unquote "$raw")" || deny "the command has an unclosed quote."
  # Discarding output is not a write; strip those redirections before looking for real ones.
  cmd="$(printf '%s' "$cmd" | sed -E 's#[0-9]*>&[0-9]+-?##g; s#&>>?[[:space:]]*/dev/null##g; s#[0-9]*>>?[[:space:]]*/dev/null##g')"
  case "$cmd" in
    *'>'*) deny "redirecting output into a file is a write. Reviewers report; they do not change anything." ;;
  esac
  while IFS= read -r segment; do
    check_readonly_segment "$segment"
  done < <(printf '%s\n' "$cmd" | sed -E 's/&&|\|\||[;|&]/\n/g')
}

guard_no_git() {
  local raw="$1"
  # Matched on the raw command on purpose, quotes included, so `bash -c "git stash"` and
  # `xargs git checkout` are caught too.
  local arg="(\"[^\"]*\"|'[^']*'|[^[:space:]]+)"
  local re="(^|[^[:alnum:]_.-])git([[:space:]]+((-C|-c|--git-dir|--work-tree|--namespace)[[:space:]]+$arg|-[^[:space:]]+))*[[:space:]]+($NO_GIT_SUBCOMMANDS)([^[:alnum:]_-]|$)"
  if [[ "$raw" =~ $re ]]; then
    deny "\"git ${BASH_REMATCH[$((${#BASH_REMATCH[@]} - 2))]}\" changes git state, and no agent may: it can destroy the user's uncommitted work. The user commits; return your result instead."
  fi
}

# Print PATH relative to the root of the git repository holding it, or PATH unchanged when it is
# outside any repository. Patterns like */test/* must not match a directory above the repo.
repo_relative() {
  local path="$1" dir rest="" root
  dir="$path"
  while [ ! -d "$dir" ]; do
    rest="/${dir##*/}$rest"
    dir="$(dirname -- "$dir")"
  done
  dir="$(cd -- "$dir" && pwd -P)" || { printf '%s' "$path"; return; }
  path="$dir$rest"
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || { printf '%s' "$path"; return; }
  printf '%s' "${path#"$root"/}"
}

is_test_path() {
  local path="/$1" base="${1##*/}"
  case "$path" in
    */test/* | */tests/* | */__tests__/* | */spec/* | */specs/* | */e2e/* | */cypress/* | \
      */testdata/* | */__mocks__/* | */__snapshots__/* | */fixtures/* | */__fixtures__/* | */factories/*)
      return 0 ;;
  esac
  case "$base" in
    *.test.* | *.spec.* | *_test.* | *_spec.* | test_*.py | conftest.py | *.snap | \
      *Test.java | *Test.kt | *Test.scala | *Test.groovy | *Test.php | *Test.cs | *Tests.cs | \
      *Tests.swift | *Spec.groovy | *Spec.scala | *Spec.kt | \
      *.fixture.* | *.fixtures.* | *_fixture.* | *_fixtures.* | *.factory.* | *_factory.* | factories.*)
      return 0 ;;
  esac
  return 1
}

is_config_path() {
  local path="/$1" base="${1##*/}"
  case "$path" in
    */.git/* | */.github/* | */.gitlab/* | */.circleci/* | */.husky/* | */.vscode/* | */.idea/* | */.claude/*)
      return 0 ;;
  esac
  case "$base" in
    .* | *.config.* | *.conf | *.conf.* | *.cfg | *.ini | *.toml | *.lock | *-lock.json | *-lock.yaml | \
      *.gemspec | package.json | composer.json | deno.json | deno.jsonc | tsconfig*.json | jsconfig*.json | \
      go.mod | go.sum | Gemfile | Rakefile | pom.xml | build.gradle* | settings.gradle* | phpunit.xml* | \
      setup.py | noxfile.py | Makefile | makefile | justfile | Justfile | Taskfile.yml | Taskfile.yaml | \
      Dockerfile* | docker-compose*.yml | docker-compose*.yaml | compose.yml | compose.yaml)
      return 0 ;;
  esac
  return 1
}

guard_file() {
  local file="$1" cwd="$2" rel
  [ -n "$file" ] || deny "the $TOOL call names no file path."
  case "$file" in
    /*) ;;
    *) file="${cwd:-$PWD}/$file" ;;
  esac
  rel="$(repo_relative "$file")"
  case "$MODE" in
    tests-only)
      is_test_path "$rel" && return 0
      case "$rel" in *.md) return 0 ;; esac
      deny "$rel is not a test file or Markdown. The tester never touches production code; report the gap instead." ;;
    src-only)
      is_test_path "$rel" && deny "$rel is a test file, fixture or factory. Mutate production source only."
      is_config_path "$rel" && deny "$rel is configuration. Mutate production source only."
      return 0 ;;
  esac
}

case "$MODE" in
  -h | --help) usage; exit 0 ;;
  readonly | no-git | tests-only | src-only) ;;
  "") usage >&2; deny "no mode given." ;;
  *) deny "unknown mode \"$MODE\". Expected readonly, no-git, tests-only or src-only." ;;
esac

command -v jq >/dev/null 2>&1 || deny "jq is not installed, so the hook input cannot be read. Every call is denied until it is."

INPUT="$(cat)"
TOOL="$(jq -er '.tool_name' <<<"$INPUT" 2>/dev/null)" || deny "the hook input is not PreToolUse JSON with a tool_name."

case "$MODE" in
  readonly | no-git)
    [ "$TOOL" = Bash ] || exit 0
    COMMAND="$(jq -r '.tool_input.command // ""' <<<"$INPUT")"
    if [ "$MODE" = readonly ]; then guard_readonly "$COMMAND"; else guard_no_git "$COMMAND"; fi
    ;;
  tests-only | src-only)
    case "$TOOL" in Edit | Write | MultiEdit | NotebookEdit) ;; *) exit 0 ;; esac
    guard_file "$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$INPUT")" \
      "$(jq -r '.cwd // ""' <<<"$INPUT")"
    ;;
esac
exit 0
