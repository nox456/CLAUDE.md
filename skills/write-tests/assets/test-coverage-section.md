## Test coverage

**Added:** YYYY-MM-DD · **Coverage:** [before]% → [after]% · **Suite run:** no — see the command below

[One or two sentences: what was tested and what was deliberately left uncovered. Link the
requirements the new tests cover.]

### Behaviors

| # | Behavior | Requirement | Status | Test |
| --- | --- | --- | --- | --- |
| B-1 | [input condition → observable outcome] | TR-n | Covered | `path/to/file.test.ts` |
| B-2 | | TR-n | Open — HIGH | — |
| B-3 | | — | Partial | `path/to/file.test.ts:44` |

Coverage = ([covered] + 0.5 × [partial]) / [total] behaviors = [after]%

### Tests added

| File | Unit under test | Cases | Kind |
| --- | --- | --- | --- |
| `path/to/file.test.ts` | `symbol` | [n] happy · [n] edge · [n] error | Unit |
| `path/to/flow.test.ts` | [the flow] | [n] | Integration |

**Run them with:** `<the command the repo defines>`

### Left uncovered

| # | Behavior | Severity | Why it was left | Owner |
| --- | --- | --- | --- | --- |
| B-2 | | HIGH / MEDIUM / LOW | [decision, not oversight] | @ |

[Delete this table if nothing was left open.]

### Expected failures

[Tests asserting what this plan specifies, against code that currently does something else.
Each one: the test, the behavior, and the bug it exposes. Delete the section if there are none.]

- `path/to/file.test.ts` — [behavior] — currently [what the code does instead].
