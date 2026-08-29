#!/usr/bin/env bash
# Snapshot / restore / verify the files a mutation run edits, without touching git.
# git checkout, git restore and git stash destroy uncommitted work; this does not.
set -uo pipefail

SNAPDIR="${MUTANT_GUARD_DIR:-${TMPDIR:-/tmp}/mutant-guard}"
MANIFEST="$SNAPDIR/manifest.tsv"

usage() {
  cat <<'USAGE'
Usage: mutant-guard.sh snapshot FILE [FILE...]
       mutant-guard.sh restore [FILE...]
       mutant-guard.sh verify [FILE...]
       mutant-guard.sh list
       mutant-guard.sh clean

Protects a mutation-testing run: copies the files that will be mutated, restores them byte for
byte, and proves nothing was left behind. Never invokes git, so uncommitted work is safe.

Commands:
  snapshot  Copy each FILE into the snapshot store. Replaces any previous store.
  restore   Copy the snapshot back over the working file. No FILE means all of them.
  verify    Diff each working file against its snapshot. Prints OK, or DIRTY + the paths.
  list      Print the manifest (snapshot path <TAB> original path).
  clean     Delete the snapshot store.

Store location: $MUTANT_GUARD_DIR, else $TMPDIR/mutant-guard, else /tmp/mutant-guard.

Exit codes:
  0  Success; for verify, every file matches its snapshot.
  1  verify found a difference, or restore/verify ran with no snapshot store.
  2  Usage error, or a named file does not exist.

Examples:
  bash scripts/mutant-guard.sh snapshot src/payments/charge.ts src/payments/export.ts
  bash scripts/mutant-guard.sh restore && bash scripts/mutant-guard.sh verify
USAGE
}

die() { echo "Error: $1" >&2; exit "${2:-2}"; }

# Map an original path to its flat slot in the store.
slot() { printf '%s/%s' "$SNAPDIR" "$(printf '%s' "$1" | sed 's|/|__|g')"; }

require_store() {
  [ -f "$MANIFEST" ] || die "no snapshot store at $SNAPDIR. Run \"snapshot FILE...\" first." 1
}

# Emit the original paths to act on: the args, or every path in the manifest.
targets() {
  if [ "$#" -gt 0 ]; then printf '%s\n' "$@"; else cut -f2 "$MANIFEST"; fi
}

cmd_snapshot() {
  [ "$#" -gt 0 ] || die "snapshot needs at least one FILE. Run --help for usage."
  local f dest
  # Validate every path before touching the store, so a bad argument cannot leave a
  # partial manifest that "restore" would then silently under-restore.
  for f in "$@"; do
    [ -f "$f" ] || die "\"$f\" is not a file. Snapshot production source files only."
  done
  rm -rf "$SNAPDIR"
  mkdir -p "$SNAPDIR" || die "cannot create snapshot store at $SNAPDIR" 2
  for f in "$@"; do
    dest="$(slot "$f")"
    cp -p -- "$f" "$dest" || die "cannot copy \"$f\" into $SNAPDIR" 2
    printf '%s\t%s\n' "$dest" "$f" >> "$MANIFEST"
  done
  echo "Snapshotted $# file(s) to $SNAPDIR"
}

cmd_restore() {
  require_store
  local f dest n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    dest="$(slot "$f")"
    [ -f "$dest" ] || die "\"$f\" was never snapshotted. Snapshot it before mutating it." 2
    cp -p -- "$dest" "$f" || die "cannot restore \"$f\"" 2
    n=$((n + 1))
  done < <(targets "$@")
  echo "Restored $n file(s) from $SNAPDIR"
}

cmd_verify() {
  require_store
  local f dest dirty=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    dest="$(slot "$f")"
    if [ ! -f "$dest" ]; then
      echo "DIRTY $f (no snapshot on record)"; dirty=1; continue
    fi
    if [ ! -f "$f" ]; then
      echo "DIRTY $f (working file is missing)"; dirty=1; continue
    fi
    cmp -s -- "$dest" "$f" || { echo "DIRTY $f"; dirty=1; }
  done < <(targets "$@")
  if [ "$dirty" -ne 0 ]; then
    echo "Mutation still on disk. Stop the run and restore before continuing." >&2
    exit 1
  fi
  echo "OK"
}

[ "$#" -gt 0 ] || { usage; exit 2; }
case "$1" in
  -h|--help) usage ;;
  snapshot)  shift; cmd_snapshot "$@" ;;
  restore)   shift; cmd_restore "$@" ;;
  verify)    shift; cmd_verify "$@" ;;
  list)      require_store; cat "$MANIFEST" ;;
  clean)     rm -rf "$SNAPDIR"; echo "Removed $SNAPDIR" ;;
  *)         die "unknown command \"$1\". Run --help for usage." ;;
esac
