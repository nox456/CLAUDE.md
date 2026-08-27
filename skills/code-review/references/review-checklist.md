# Review checklist

Run in step 5, before showing the user anything. Every unchecked box is a fix to the draft,
not a caveat to mention.

## Scope

- [ ] Every finding's fix **changes observable behavior**. Nothing survives whose fix is only
      cleaner, shorter, more consistent, or better named.
- [ ] No finding is about duplication, dead code, file placement, naming, or repo conventions.
      (Duplication counts only when the copies have *diverged* — and then the finding is the
      divergence, with the behavior it produces.)
- [ ] Nothing reported is listed in the document's **Out of scope** or open questions.
- [ ] Pre-existing bugs outside the reviewed change are excluded, unless the change now routes
      real traffic into them — in which case that is the finding.

## Grounding

- [ ] The spec document was actually read this run, and passes 1 and 2 were both run against it.
- [ ] Every numbered requirement in the document was traced to code — including the ones that
      turned out fine.
- [ ] Every finding names code read at the reviewed ref; no finding rests on an assumed
      implementation of a function that was never opened.
- [ ] Unconfirmed suspicions are either dropped or explicitly flagged as unconfirmed in the
      Description, and none of those is rated above MEDIUM.

## Format

- [ ] Every finding has all five lines — title, Severity, Location, Description, Suggestion —
      in that order, with no commentary between findings.
- [ ] Findings are sorted by severity descending and numbered from 1 with no gaps.
- [ ] Each `path:line` was verified against the file at the reviewed ref, not read off a diff
      hunk header.
- [ ] Multi-file findings use `Multiple locations: <file>, <file>` and carry no line numbers.
- [ ] Descriptions are 1–2 sentences, naming cause *and* consequence — not a restatement of the
      title.
- [ ] Every code-located finding has a concrete Suggestion using the repo's real identifiers,
      types, and language; action-only suggestions are one short sentence.
- [ ] Duplicate reports of one defect are merged into a single finding.

## Severity and verdict

- [ ] Each label was checked against the anchor table, not assigned by feel. In particular:
      BLOCKING is reserved for data/money/auth/production-breakage or an unimplemented stated
      requirement.
- [ ] The severity counts in the verdict match the findings list.
- [ ] The arithmetic is shown and correct, the BLOCKING cap applied, the score floored at 0.
- [ ] The band's wording matches the score, and the "must fix before merge" shortlist contains
      every BLOCKING and HIGH — and nothing else.

## Conduct

- [ ] No file was edited or created, no test suite or formatter run, nothing posted to GitHub.
- [ ] Next steps (re-review, `refactor-review`, posting to the PR) are offered, not performed.
