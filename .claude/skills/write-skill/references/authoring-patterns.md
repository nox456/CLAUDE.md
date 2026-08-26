# Authoring patterns

Read while drafting the body (Step 4). Everything here is downstream of one question, asked of
every line you write: **would the agent get this wrong without it?** If no, cut it.

## Calibrate control per section

Prescriptiveness is not a house style — it is a per-instruction decision.

| The task is | Write it as | Because |
| --- | --- | --- |
| Fragile, order-dependent, destructive, or must be byte-identical | An exact command or sequence, plus "do not add flags" | Variation breaks it |
| Open-ended with several valid routes | The goal, the constraints, and *why* | An agent that knows the purpose adapts better than one following a rigid script into a case you never saw |

Most skills mix both. A migration command is exact; the review pass around it is not.

## Procedures, not answers

Teach how to approach the class of problem, not what to output for one instance. "Join `orders`
to `customers` on `customer_id`" helps once; "read the schema from `references/schema.yaml`, join
on the `_id` convention, apply the request's filters" works for every query. Specific details
still belong in the skill — output templates, hard constraints, tool names — but the *method*
must generalise.

## Defaults, not menus

"You can use pypdf, pdfplumber, PyMuPDF, or pdf2image" makes the agent shop. "Use pdfplumber;
for scanned PDFs use pdf2image with pytesseract" makes it work. One default, one named escape
hatch.

## Patterns worth reaching for

Pick what fits; a skill needs none of them by default.

- **Gotchas.** The highest-value section in most skills: environment facts that defy reasonable
  assumptions ("`users` uses soft deletes — filter `deleted_at IS NULL`", "`/health` returns 200
  with the database down, use `/ready`"). Concrete corrections, never "handle errors properly".
  Keep them in `SKILL.md` — the agent cannot know to open a reference for a trap it does not
  know exists. Every time the user corrects the agent, the correction belongs here.
- **Output templates.** Agents pattern-match a concrete structure better than they follow prose
  about one. Short template inline; long or conditional template in `assets/`.
- **Checklists.** For multi-step workflows with dependencies or gates, so the agent can track
  where it is and not skip a step.
- **Validation loops.** Do the work → run a validator (script, reference checklist, or
  self-check) → fix → repeat until clean → only then proceed.
- **Plan-validate-execute.** For batch or destructive work: write the plan to a structured file,
  validate it against a source of truth, then execute. The validation step is what makes it
  worth the ceremony, and its error messages must name what was wrong *and* what was expected.

## Bundling scripts

Add a script when the agent would otherwise rebuild the same logic every run, or when a command
is too intricate to get right first try. Otherwise prefer a pinned one-off command
(`npx eslint@9 --fix .`, `uvx ruff@0.8.0 check .`) and state the prerequisite — runtime-level
requirements go in the `compatibility` frontmatter field.

List scripts in `SKILL.md` with one line each on what they do, and invoke them by relative path
from the skill root.

Make each script self-contained: inline dependency metadata (PEP 723 + `uv run` for Python,
`npm:`/`jsr:` specifiers for Deno, pinned imports for Bun, `bundler/inline` for Ruby) beats a
manifest the agent has to install.

Design the interface for a non-interactive reader:

- **Never prompt.** Agents run in non-interactive shells; a TTY prompt hangs forever. Take input
  through flags, env vars, or stdin, and fail with a usage message naming the missing flag.
- **`--help` is the contract.** Description, flags, defaults, one or two examples. Keep it short
  — it lands in the context window.
- **Errors that shape the retry.** What went wrong, what was expected, what to try:
  `Error: --format must be one of json, csv, table. Received: "xml"`.
- **Structured stdout, diagnostics on stderr.** JSON/CSV/TSV over aligned text, so the output
  composes with `jq` and friends.
- **Idempotent, with meaningful exit codes** documented in `--help`; `--dry-run` for anything
  destructive; a bounded default output size with a flag to ask for more, since harnesses
  truncate long tool output.
