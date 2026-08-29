---
name: write-skill
description: Author or revise an Agent Skill (a SKILL.md and its bundled files) so it follows the published agentskills.dev spec and best practices — read the spec from the agentskills MCP server first, ground the skill in real expertise instead of generic advice, keep SKILL.md inside the progressive-disclosure budget, write a description that triggers reliably, then validate with scripts/validate-skill.sh. Use when asked to "create a skill", "write a skill", "turn this into a skill", "make a slash command", "review/improve/split this skill", "why doesn't my skill trigger", or when invoked as /write-skill. Use it before editing any SKILL.md or its frontmatter, even for a one-line change.
---

# Write an Agent Skill

Produces a skill an agent actually activates and can follow, in the format defined at
agentskills.dev. It exists to prevent the two ways skill authoring usually fails: a skill
generated from a one-line prompt (generic advice the agent already knew) and a skill written
from memory of the spec (invalid frontmatter, a bloated body, a description that never fires).

## Ground rules

- **Docs first, memory never.** The `agentskills` MCP server is the source of truth for the
  spec and the best practices. Read the pages the task needs (Step 1) before writing anything.
  Where the MCP disagrees with this skill's `references/`, the MCP wins — follow it, and fix the
  stale reference file.
- **No expertise, no skill.** A skill's value is the project-specific procedure, gotcha, or
  convention the agent would otherwise get wrong. If there is no such source material, stop and
  get it (Step 2) rather than filling a template with plausible-sounding advice.
- **Add what the agent lacks; cut what it already knows.** Every line competes for attention
  with the rest of the context window. If the agent does it right without the instruction, the
  instruction is noise.
- **Progressive disclosure is a budget, not a style.** `SKILL.md` stays under 500 lines and
  ~5,000 tokens. Overflow moves to `references/`, `assets/`, or `scripts/` — each with an
  explicit "read this when X" trigger, never a bare "see references/".
- **Defaults, not menus.** Pick one approach and name the escape hatch. A list of equal options
  makes the agent shop around instead of working.
- **Never ship unvalidated.** `scripts/validate-skill.sh` must pass with zero errors, and the
  review checklist must be run, before you hand the skill back.
- **Touch only the skill you were asked about.** Do not refactor neighbouring skills, and do not
  commit, push, or link anything unless the user asks in that turn.

## Workflow

- [ ] Step 1 — Load the docs (hard gate)
- [ ] Step 2 — Scope it and source the expertise
- [ ] Step 3 — Choose the layout
- [ ] Step 4 — Write `SKILL.md` and its files
- [ ] Step 5 — Write the description last
- [ ] Step 6 — Validate and self-review
- [ ] Step 7 — Update the README skills table
- [ ] Step 8 — Install and hand off

---

### Step 1 — Load the docs (hard gate)

Two MCP tools serve the docs:

- `mcp__agentskills__search_agent_skills` — conceptual search ("how should a skill bundle
  scripts").
- `mcp__agentskills__query_docs_filesystem_agent_skills` — read pages by path with a
  shell-like command (`cat /specification.mdx`). Paths need the `.mdx` suffix, and one call can
  take several paths (`head -200 /a.mdx /b.mdx`).

If those tools are not in the tool list yet, load their schemas first:
`ToolSearch("select:mcp__agentskills__search_agent_skills,mcp__agentskills__query_docs_filesystem_agent_skills")`.

Read what the task needs — not the whole site:

| Page | Read when |
| --- | --- |
| `/specification.mdx` | Always. Frontmatter fields, limits, directory layout, file references |
| `/skill-creation/best-practices.mdx` | Always. Scoping, context budget, control calibration, patterns |
| `/skill-creation/optimizing-descriptions.mdx` | Writing a description, or fixing one that mis-triggers |
| `/skill-creation/using-scripts.mdx` | The skill will bundle a script or run a command |
| `/skill-creation/evaluating-skills.mdx` | The skill needs evals, or you are iterating on an existing one |
| `/clients.mdx`, `/client-implementation/adding-skills-support.mdx` | Where a client discovers skills, or you are building one |

Say which pages you read. If the MCP server is unreachable, say so plainly, work from
`references/` marked as an unverified cache, and repeat the caveat in the handoff — do not
silently fall back to memory.

### Step 2 — Scope it and source the expertise

**Scope it like a function.** One coherent unit of work that composes with other skills. Too
narrow and several skills must load for one task; too broad and it never triggers precisely.
Check for an existing skill that already owns this ground (`ls` the skills directories) — extend
it rather than adding a near-duplicate that competes for the same triggers.

**Then get the real material.** Best sources, in order:

1. A real task just completed in this conversation — the steps that worked, and every place the
   user corrected the approach.
2. Project artifacts: runbooks, style guides, `CLAUDE.md`/`AGENTS.md`, API specs, schemas,
   review comments, past incidents, and the diffs that fixed them.
3. The user's own head — interview for it.

Ask (`AskUserQuestion`, at most a couple of rounds) only what changes the skill: what the agent
currently gets wrong, the non-obvious constraints, the required output shape, what is out of
scope. If the answer is "nothing specific — just write something good", say that a skill built
on that will only restate what the agent already does, and offer to run the task once together
and extract the skill from the transcript.

### Step 3 — Choose the layout

Start with one file and grow only under pressure:

| Add | When |
| --- | --- |
| `SKILL.md` alone | Default. The whole procedure fits in the budget |
| `references/*.md` | Detail needed only in some runs — each with a stated load trigger |
| `assets/*` | Output templates, config skeletons, lookup data the agent copies or fills |
| `scripts/*` | The agent would otherwise reinvent the same logic every run, or the step is fragile enough to need a tested command |
| `evals/evals.json` | The skill will be iterated on against test prompts |

Keep references one level deep from `SKILL.md`; no reference chains.

### Step 4 — Write `SKILL.md` and its files

Copy `assets/skill-template.md` as the skeleton, then read
`references/authoring-patterns.md` before filling it in — it covers how prescriptive each part
should be, and the patterns worth reaching for (gotchas, output templates, checklists,
validation loops, plan-validate-execute) plus how to design a bundled script for agent use.

Non-negotiables while drafting:

- `name`: lowercase letters, digits and single hyphens, ≤64 chars, **identical to the directory
  name**, and matching the sibling skills' naming style.
- Body opens with what the skill produces and the ground rules that constrain it, then a
  numbered workflow. Imperative voice, second person, no narration of what the skill "is".
- Every bundled file is named in `SKILL.md` with the condition for reading or running it, by
  relative path from the skill root (`references/foo.md`, never an absolute path).
- Gotchas — environment facts that defy reasonable assumptions — belong in `SKILL.md` itself,
  where they are read before the mistake, not in a reference the agent must know to open.

### Step 5 — Write the description last

The description is the only thing loaded at startup, so it decides whether the skill ever runs.
Write it after the body, when the scope is settled, following
`references/description-tuning.md`: what it does, when to use it, the phrasings a user actually
types, and — when a neighbouring skill is close — what it does *not* cover. Under 1024
characters, imperative, no marketing.

For an existing skill that mis-triggers, that reference also carries the eval loop (query set,
trigger rate, train/validation split) — that is the fix, not a hopeful reword.

### Step 6 — Validate and self-review

```bash
bash .claude/skills/write-skill/scripts/validate-skill.sh <path-to-skill-dir>
```

It checks the mechanical spec rules (frontmatter, name, limits, budget, resolvable references,
orphan files) and prints `ERROR`/`WARN` lines. Fix every `ERROR` and re-run until clean; justify
or fix each `WARN`. Then walk `references/review-checklist.md` — it catches what a validator
cannot: generic filler, hidden menus, missing triggers, wrong altitude.

If the skill is high-stakes or being iterated on, run it once against a real task in a fresh
context (a subagent is enough) and fix what the trace exposes: steps skipped, instructions
ignored, time lost to vagueness.

### Step 7 — Update the README skills table

Every git-tracked skill in `skills/` has a row in the **Skills** table in `README.md`. Two kinds
are deliberately absent: skills in `.claude/skills/` (repo-only tooling, `write-skill` included),
and gitignored skills in `skills/` (private, work-specific ones — check with
`git check-ignore skills/<name>` before adding a row). For a new skill, add its row in the
table's existing order — authoring, then execution, then review, then standalone skills:

| Column | Value |
| --- | --- |
| Name | The skill name, linked to its directory: `[name](skills/name/)` |
| Description | One sentence saying what the skill produces — not when it triggers |
| Depends on | The skills whose output it consumes or that it delegates to, in backticks; `—` if none |

For a revision, touch the row only when the name, the scope, or a dependency actually changed.
Renaming a skill means fixing its link *and* every `Depends on` cell that names it.

### Step 8 — Install and hand off

Place the directory where this project's client looks for it. Detect, do not assume: in this
repo general-use skills live in `skills/<name>/` and `./install.sh` symlinks them into
`~/.claude/skills/` (new directories need one `install.sh` run; later edits are live through the
symlink), while skills meant only for this repo live in `.claude/skills/<name>/`. Elsewhere
check for `.claude/skills/`, `~/.claude/skills/`, or `.agents/skills/` and follow what is there.

Report: the path, what the skill covers and deliberately excludes, the files bundled and when
each loads, validator output, unresolved `WARN`s, the README row added or updated, and how to
try it (`/<name>`, or a prompt that
should trigger it). Offer a Conventional Commits message matching the repo's history — do not
stage or commit.

## Gotchas

- `name` and the directory name must match exactly. Renaming a skill means renaming the
  directory, and in this repo re-running `./install.sh` to prune the stale symlink.
- A description over 1024 chars, an uppercase or double-hyphened `name`, or a missing
  `description` makes the skill invalid — clients may skip it silently, with no error to notice.
- `metadata` values are strings: `version: "1.0"`, not `version: 1.0`.
- `allowed-tools` is experimental and client-specific; do not rely on it for correctness.
- Commands in code blocks — in `SKILL.md` *and* in `references/*.md` — resolve relative to the
  skill root, because that is where the agent runs them from.
- "This skill helps with X" descriptions trigger worse than "Use when the user asks to X".
  Include the domain keywords *and* the case where the user never names the domain.
- One-step tasks the agent already handles may not trigger a skill however good the description
  is. That is a sign the skill is not needed, not a description bug.
- A skill that restates general knowledge is worse than no skill: it burns context and dilutes
  the triggers of the skills that matter. Recommend deleting instead of shipping it.
