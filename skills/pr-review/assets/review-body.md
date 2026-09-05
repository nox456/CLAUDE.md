<!-- Template for the review's summary comment (the "central" comment). Fill it, delete the
     sections that are empty, and pass the result to --body-file. Keep the counts, the
     arithmetic and the verdict exactly as `code-review` produced them. -->

## Code review — {N} finding(s)

Reviewed `{head-sha-short}` against **{document title}** (`{path or issue link}`).
{One sentence naming what the PR is supposed to do, from the document — so a reader can see
what the review was judged against.}

**{n} blocking · {n} high · {n} medium · {n} low** — {n} of them are inline on the diff below.

### Must fix before merge

- **BLOCKING** — {title} · `{path}:{line}`
- **HIGH** — {title} · `{path}:{line}`

### Also found

- **MEDIUM** — {title} · `{path}:{line}`
- **LOW** — {title} · `{path}:{line}`

### Findings with no line in this diff

<!-- Findings the diff cannot carry — a requirement nothing implements, a defect spanning
     several files, a line the PR did not touch. These get their full five-line form here,
     because no inline comment carries them. Delete the section if there are none. -->

**{title}**
Severity: {LEVEL}
Location: {Multiple locations: a.ts, b.ts | the artifact that should have contained it}
Description: {cause and consequence}
Suggestion: {the fix}

### Merge readiness

```
Score = 100 − (40 × {b}) − (15 × {h}) − (5 × {m}) − (1 × {l}) = {score}
{Any BLOCKING caps the score at 35 — state the cap only when it actually applied.}
```

**{score}/100 — {Merge | Merge after fixes | Changes required | Do not merge}.**
{One sentence on what would move it into the next band.}

---
<sub>Automated review — findings only, no code was changed.</sub>
