# Tuning the description

The `name` and `description` are the only parts loaded at startup, so the description decides
whether the skill is ever read. Under-specified, it stays dormant; over-broad, it hijacks
unrelated tasks.

## Writing it

- **Imperative, aimed at the agent.** "Use when the user asks to …", not "This skill provides …"
  The agent is deciding whether to act.
- **Both halves, in one breath.** What it does *and* when to use it. Either alone under-triggers.
- **User intent over mechanics.** Describe the request, not the implementation. The match is
  against what the user typed.
- **Quote the real phrasings.** Include the words users actually type, including the casual and
  abbreviated ones, and the case where they never name the domain at all ("even if they don't
  mention 'CSV'").
- **Draw the boundary when a neighbour is close.** One clause on what this skill does *not*
  cover prevents both skills firing on the same prompt.
- **≤1024 characters**, a few sentences to a short paragraph. Descriptions grow during tuning —
  re-check the length after every edit.

```yaml
# Before
description: Process CSV files.

# After
description: >
  Analyze CSV and tabular data files — summary statistics, derived columns, charts, and
  cleaning messy data. Use when the user has a CSV, TSV, or Excel file and wants to explore,
  transform, or visualize it, even if they don't explicitly mention "CSV" or "analysis".
```

## Fixing one that mis-triggers

Guessing at wordings does not converge. Run the loop.

1. **Build ~20 eval queries**, 8–10 `should_trigger: true` and 8–10 `false`, as realistic
   prompts: file paths, real column and product names, personal context ("my manager asked…"),
   varied length, formality, and typos.
   - The positives that teach you something are the ones where the skill helps but the link is
     not obvious from the query. A query that names exactly what the skill does proves nothing.
   - The negatives that teach you something are **near misses** — same keywords, different need
     ("update the formulas in my Excel budget" for a CSV *analysis* skill). "Write a fibonacci
     function" tests nothing.
2. **Split ~60/40 into train and validation**, each with a proportional mix, and keep the split
   fixed across iterations.
3. **Measure the trigger rate**: run each query ~3 times and record the fraction of runs that
   loaded the skill. Pass = rate above 0.5 for positives, below it for negatives. Detection can
   read the harness's own logs — with Claude Code, look for a `Skill` tool call naming the skill
   in `claude -p "<query>" --output-format json`. The full script is in
   `/skill-creation/optimizing-descriptions.mdx` on the MCP server.
4. **Revise from train failures only.** Positives failing → too narrow, broaden the stated
   scope. Negatives firing → too broad, add specificity or state the boundary. Generalise the
   *category* a failed query represents; do not paste its keywords in, which is overfitting.
5. **Repeat up to ~5 iterations**, then pick the iteration with the best *validation* pass rate
   — often not the last one. If nothing improves, try a structurally different description
   rather than another tweak; if that fails too, suspect the query set.
6. **Sanity-check** the winner on 5–10 fresh queries that never took part in the tuning.
