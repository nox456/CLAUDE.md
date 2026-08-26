---
name: <directory-name>
description: <What it does — the concrete capability, in one clause.> Use when <the situations and the phrasings a user actually types>, or when invoked as /<directory-name>. <Optional: does not cover <adjacent skill's ground>.>
---

# <Imperative title: what the agent will do>

<Two or three lines: what this produces, and the failure it exists to prevent. No "this skill
is a…" framing.>

## Ground rules

<The constraints that hold for the whole run — the things the agent would otherwise get wrong.
Bold lead-in, then the reason. Delete this section if there are none; do not pad it.>

- **<Rule>.** <Why it matters / what goes wrong without it.>
- **<Hard gate>.** <What to do instead when the precondition is missing.>

## Workflow

- [ ] Step 1 — <verb + object>
- [ ] Step 2 — <verb + object>
- [ ] Step 3 — <verb + object>

---

### Step 1 — <name>

<Exact commands where the step is fragile; goal plus constraints where the agent needs room.>

```bash
<pinned command, if any>
```

### Step 2 — <name>

<Point at bundled files with their load condition:>
Read `references/<topic>.md` when <condition>. Fill `assets/<template>.md`. Run
`scripts/<tool>.sh <args>` to <purpose>.

### Step 3 — <name>

<How the run ends: what to validate, what to report, and what to leave for the user to decide.>

## Gotchas

<Environment facts that defy reasonable assumptions. Concrete, not general advice. This is
usually the most valuable section — grow it every time the agent has to be corrected.>

- <The trap, then the rule that avoids it.>
