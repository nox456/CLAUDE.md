# CLAUDE.md

Personal Claude Code configuration: global instructions and custom skills.

The real files live here and are symlinked into `~/.claude/`, so editing them in
this repo updates Claude Code immediately — no copy step, nothing to keep in sync.

## Layout

```
CLAUDE.md              ->  ~/.claude/CLAUDE.md
skills/<name>/         ->  ~/.claude/skills/<name>
install.sh                 creates/refreshes the symlinks
```

## Setup on a new machine

```bash
git clone <this-repo> ~/Documents/Projects/CLAUDE.md
cd ~/Documents/Projects/CLAUDE.md
./install.sh
```

`install.sh` is idempotent. It backs up any real file it would replace to
`<name>.bak.<timestamp>`, and removes stale symlinks left behind by skills that
were deleted from the repo.

Set `CLAUDE_CONFIG_DIR` to link somewhere other than `~/.claude`.

## Adding a skill

Create `skills/<name>/SKILL.md` here, then run `./install.sh` to link it.
