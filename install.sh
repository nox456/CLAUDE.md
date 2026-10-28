#!/usr/bin/env bash
# Link the files tracked in this repo into ~/.claude/ so Claude Code picks them up.
# Safe to re-run: it is idempotent and backs up anything real it would overwrite.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"

link() {
  local src="$1" dest="$2"

  if [ -L "$dest" ]; then
    if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
      echo "ok      $dest"
      return
    fi
    echo "relink  $dest (was -> $(readlink "$dest"))"
    rm "$dest"
  elif [ -e "$dest" ]; then
    echo "backup  $dest -> $dest.bak.$STAMP"
    mv "$dest" "$dest.bak.$STAMP"
  fi

  ln -s "$src" "$dest"
  echo "linked  $dest -> $src"
}

# Drop symlinks in ~/.claude/<dir> that still point into this repo's <dir> but whose source is
# gone (i.e. deleted from the repo). Other symlinks are left alone.
prune() {
  local dir="$1" dest target
  for dest in "$CLAUDE_DIR/$dir"/*; do
    [ -L "$dest" ] || continue
    target="$(readlink "$dest")"
    case "$target" in
      "$REPO/$dir"/*)
        if [ ! -e "$target" ]; then
          echo "prune   $dest (source removed from repo)"
          rm "$dest"
        fi
        ;;
    esac
  done
}

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/hooks"

link "$REPO/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

for skill in "$REPO"/skills/*/; do
  [ -d "$skill" ] || continue
  link "${skill%/}" "$CLAUDE_DIR/skills/$(basename "$skill")"
done

for agent in "$REPO"/agents/*.md; do
  [ -f "$agent" ] || continue
  link "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
done

for hook in "$REPO"/hooks/*; do
  [ -f "$hook" ] || continue
  link "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
done

prune skills
prune agents
prune hooks
