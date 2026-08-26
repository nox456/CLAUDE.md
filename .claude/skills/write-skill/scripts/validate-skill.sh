#!/usr/bin/env bash
# Validate an Agent Skill directory against the mechanical rules of the agentskills.dev spec.
# See --help. Judgement calls live in references/review-checklist.md, not here.
set -uo pipefail

MAX_NAME=64
MAX_DESC=1024
MAX_COMPAT=500
MAX_LINES=500
MAX_TOKENS=5000
KNOWN_KEYS="name description license compatibility metadata allowed-tools"

usage() {
  cat <<'USAGE'
Usage: validate-skill.sh [--json] SKILL_DIR [SKILL_DIR...]

Checks a skill directory against the agentskills.dev spec: frontmatter fields and limits,
name/directory agreement, the progressive-disclosure budget for SKILL.md, whether every
relative path named in SKILL.md resolves, and whether every bundled file is referenced.

Options:
  --json      One JSON object per finding on stdout (level, skill, message).
  -h, --help  Show this help.

Exit codes:
  0  No errors (warnings may still be printed).
  1  At least one ERROR — the skill is invalid or over budget.
  2  Usage error (no directory given, or the path is not a directory).

Examples:
  validate-skill.sh .claude/skills/write-skill
  validate-skill.sh --json skills/*/ | jq -r 'select(.level=="ERROR")'
USAGE
}

JSON=0
DIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown option \"$1\". Run --help for usage." >&2; exit 2 ;;
    *) DIRS+=("$1") ;;
  esac
  shift
done
[ ${#DIRS[@]} -gt 0 ] || { echo "Error: no SKILL_DIR given. Run --help for usage." >&2; exit 2; }

errors=0
warns=0
skill=""

say() { # level, message
  if [ "$JSON" = 1 ]; then
    printf '{"level":"%s","skill":"%s","message":"%s"}\n' "$1" "$skill" "$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  else
    printf '%-5s %s: %s\n' "$1" "$skill" "$2"
  fi
}
err()  { errors=$((errors + 1)); say ERROR "$1"; }
warn() { warns=$((warns + 1)); say WARN "$1"; }

# Read a frontmatter body on stdin; print "key<TAB>value" for each top-level key,
# folding continuation lines into the key above them.
parse_frontmatter() {
  awk '
    /^[A-Za-z][A-Za-z0-9_-]*:/ {
      key = $0; sub(/:.*/, "", key)
      val = $0; sub(/^[^:]*:[[:space:]]*/, "", val)
      sub(/^[|>][-+0-9]*[[:space:]]*/, "", val)
      if (!(key in seen)) { seen[key] = 1; order[++n] = key }
      value[key] = val; last = key; next
    }
    /^[[:space:]]+[^[:space:]]/ {
      if (last != "") {
        v = $0; sub(/^[[:space:]]+/, "", v)
        value[last] = (value[last] == "" ? v : value[last] " " v)
      }
      next
    }
    END { for (i = 1; i <= n; i++) printf "%s\t%s\n", order[i], value[order[i]] }
  '
}

validate() {
  local dir="${1%/}"
  skill="$dir"

  [ -d "$dir" ] || { err "not a directory"; return; }
  local md="$dir/SKILL.md"
  [ -f "$md" ] || { err "no SKILL.md — a skill is a directory containing SKILL.md"; return; }

  # --- frontmatter block -----------------------------------------------------
  if [ "$(head -n 1 "$md")" != "---" ]; then
    err "SKILL.md must start with a '---' YAML frontmatter fence on line 1"
    return
  fi
  local fm_end
  fm_end=$(awk 'NR > 1 && /^---[[:space:]]*$/ { print NR; exit }' "$md")
  if [ -z "$fm_end" ]; then
    err "frontmatter is never closed — add a '---' line after the last field"
    return
  fi

  local fm
  fm=$(awk -v e="$fm_end" 'NR > 1 && NR < e' "$md" | parse_frontmatter)

  local name="" desc="" compat=""
  while IFS=$'\t' read -r key val; do
    [ -n "$key" ] || continue
    case " $KNOWN_KEYS " in
      *" $key "*) ;;
      *) warn "unknown frontmatter key \"$key\" — spec defines: $KNOWN_KEYS" ;;
    esac
    case "$key" in
      name) name="$val" ;;
      description) desc="$val" ;;
      compatibility) compat="$val" ;;
    esac
  done <<< "$fm"

  # --- name ------------------------------------------------------------------
  if [ -z "$name" ]; then
    err "frontmatter is missing the required \"name\" field"
  else
    [ ${#name} -le $MAX_NAME ] || err "name is ${#name} chars, max is $MAX_NAME"
    if ! printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
      err "name \"$name\" is invalid — lowercase a-z, 0-9 and single hyphens only, no leading/trailing hyphen"
    fi
    local base
    base="$(basename "$dir")"
    [ "$name" = "$base" ] || err "name \"$name\" must match the directory name \"$base\""
  fi

  # --- description -----------------------------------------------------------
  if [ -z "$desc" ]; then
    err "frontmatter is missing the required \"description\" field — it is what makes the skill trigger"
  else
    [ ${#desc} -le $MAX_DESC ] || err "description is ${#desc} chars, max is $MAX_DESC"
    [ ${#desc} -ge 40 ] || warn "description is only ${#desc} chars — say what it does AND when to use it"
    printf '%s' "$desc" | grep -qiE 'use (this skill )?(when|for)|when (the user|asked|invoked)' \
      || warn "description states no trigger — add \"Use when the user asks to ...\" phrasing"
  fi

  [ -z "$compat" ] || [ ${#compat} -le $MAX_COMPAT ] \
    || err "compatibility is ${#compat} chars, max is $MAX_COMPAT"

  # --- context budget --------------------------------------------------------
  local lines chars tokens
  lines=$(wc -l < "$md" | tr -d ' ')
  chars=$(wc -c < "$md" | tr -d ' ')
  tokens=$(( chars / 4 ))
  [ "$lines" -le $MAX_LINES ] \
    || err "SKILL.md is $lines lines, over the $MAX_LINES-line budget — move detail into references/"
  [ "$tokens" -le $MAX_TOKENS ] \
    || err "SKILL.md is ~$tokens tokens, over the ~$MAX_TOKENS-token budget — move detail into references/"

  # --- referenced paths resolve ---------------------------------------------
  local refs ref
  refs=$(grep -oE '(references|assets|scripts|evals)/[A-Za-z0-9._/-]+' "$md" | sed 's/[.,:;)]*$//' | sort -u)
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    # Stand-in names used when documenting path syntax, never real bundles.
    case "$(basename "$ref")" in
      foo.*|bar.*|baz.*|qux.*|example.*|placeholder.*) continue ;;
    esac
    [ -e "$dir/$ref" ] && continue
    if [ -d "$dir/${ref%%/*}" ]; then
      err "SKILL.md references \"$ref\", which does not exist"
    else
      warn "SKILL.md mentions \"$ref\", which is not bundled (illustrative path?)"
    fi
  done <<< "$refs"

  # --- bundled files are reachable ------------------------------------------
  local f rel
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$dir"/}"
    grep -qF "$rel" "$md" && continue
    if ls "$dir"/references/*.md >/dev/null 2>&1 && grep -qrF "$rel" "$dir"/references/*.md; then
      continue
    fi
    warn "\"$rel\" is never referenced from SKILL.md — the agent will not know it exists"
  done < <(find "$dir" -mindepth 2 -path "$dir/evals" -prune -o -type f -print 2>/dev/null | sort)

  # --- reference depth and script hygiene -----------------------------------
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    warn "\"${f#"$dir"/}\" is more than one level deep — keep references flat"
  done < <(find "$dir" -mindepth 3 -type f -not -path "$dir/evals/*" 2>/dev/null | sort)

  if [ -d "$dir/scripts" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      head -n 1 "$f" | grep -q '^#!' || warn "\"${f#"$dir"/}\" has no shebang line"
      [ -x "$f" ] || warn "\"${f#"$dir"/}\" is not executable — invoke it as \`bash <path>\` or chmod +x"
    done < <(find "$dir/scripts" -type f 2>/dev/null | sort)
  fi
}

for d in "${DIRS[@]}"; do validate "$d"; done

if [ "$JSON" = 0 ]; then
  printf '\n%d error(s), %d warning(s) across %d skill(s)\n' "$errors" "$warns" "${#DIRS[@]}"
  [ "$errors" -eq 0 ] && echo "Spec checks passed. Now walk references/review-checklist.md."
fi
[ "$errors" -eq 0 ]
