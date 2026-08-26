# Review checklist

Run after `scripts/validate-skill.sh` is clean (Step 6). The validator covers the mechanical
rules; this covers the judgement calls it cannot see. Answer each item out loud — an unchecked
box is a fix, not a caveat.

## Does it deserve to exist

- [ ] A capable agent **without** this skill would get the task wrong, slower, or inconsistent.
      If not, recommend deleting it.
- [ ] It is one coherent unit of work, not two skills sharing a directory, and not a fragment
      that needs a sibling skill loaded to be useful.
- [ ] No existing skill already owns these triggers.
- [ ] Nothing in it is general knowledge (what a PDF is, how HTTP works, "handle errors
      appropriately", "follow best practices").

## Grounding

- [ ] Every convention, threshold, path, and command came from the user or a source in the
      project — none was inferred to fill a section.
- [ ] The gotchas are real corrections to real mistakes, phrased concretely enough to act on.
- [ ] No invented file paths, table names, flags, or scripts. Each one named was verified to
      exist.

## Frontmatter and triggering

- [ ] `name` matches the directory, lowercase-hyphen, ≤64 chars, consistent with sibling skills.
- [ ] `description` states what it does *and* when to use it, imperative, ≤1024 chars, using the
      phrasings a user would actually type.
- [ ] Where a neighbouring skill is close, the boundary is stated.
- [ ] `compatibility` present only if the skill genuinely needs a runtime, package, or network
      access; `metadata` values quoted as strings.

## Context budget

- [ ] `SKILL.md` under 500 lines and ~5,000 tokens, and everything left in it is needed on
      *every* run.
- [ ] Each bundled file has an explicit load trigger ("read X when the API returns non-200"),
      not a bare "see references/".
- [ ] References are one level deep, no chains, no absolute paths.
- [ ] No file in the directory is unreferenced from `SKILL.md`, and nothing referenced is
      missing.

## Instructions

- [ ] Prescriptive exactly where the task is fragile; explains *why* where the agent needs room.
- [ ] Every choice has a default; no menus of equal options.
- [ ] Procedures generalise to the class of task — not one worked example dressed as a rule.
- [ ] Multi-step flows have a checklist, and gates have a validation step with a way to know it
      passed.
- [ ] The output format is shown as a template, not described in prose.
- [ ] Nothing contradicts anything else in the file, and no step depends on state an earlier step
      never produced.

## Scripts, if any

- [ ] No interactive prompts anywhere.
- [ ] `--help` documents flags, defaults, exit codes, and one example.
- [ ] Errors say what was wrong and what was expected; data on stdout, diagnostics on stderr.
- [ ] Idempotent; destructive paths need an explicit flag; output size is bounded.
- [ ] It runs. It was actually executed once from the skill root before shipping.
