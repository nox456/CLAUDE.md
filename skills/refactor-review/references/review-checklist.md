# Review checklist

Run in step 5, before showing the user anything. Every unchecked box is a fix to the draft, not
a caveat to mention.

## Scope

- [ ] Every finding is **behavior-preserving** — the two-sentence behavior check was run and the
      before and after sentences match.
- [ ] No finding belongs to `code-review`: no bugs, unmet requirements, contract mismatches, or
      broken edge cases carry a number and a severity here.
- [ ] No finding rests only on line count. Every one names a maintenance cost.
- [ ] Duplication findings are copies **this change introduced**, not pre-existing pairs.
- [ ] Nothing reported is in a generated file, lockfile, or migration output.
- [ ] Test findings clear the higher bar: an existing fixture or builder the new tests ignore.

## Thresholds

- [ ] No duplication finding is a 2-copy block of 5 lines or fewer, unless the copies encode one
      business rule.
- [ ] Every extraction proposal survived the coincidental-duplication question; none of them
      results in a shared function with a mode flag.
- [ ] Every util-file finding counted only functions that are free of the module's state and
      scope, crossed the "more than 3" line, and is **one** finding for the file.
- [ ] Every extraction names a real target path that all call sites can import without creating
      a cycle.

## Grounding

- [ ] Every convention finding cites its source — a documented rule, or two or more sibling
      files. None was inferred from one file or from general style opinion.
- [ ] Every Location names code read at the reviewed ref; every duplication finding lists every
      copy actually found.
- [ ] `rg` was run for any symbol a finding proposes renaming, moving, or deleting, and the
      result is reflected in the severity.
- [ ] Every path, file, function, and identifier named in a Suggestion was verified to exist.

## Format

- [ ] Every finding has all six lines — title, Severity, Location, Description, Suggestion,
      Improving — in that order, with no commentary between findings.
- [ ] Findings are sorted by severity descending and numbered from 1 with no gaps.
- [ ] Each `path:line` was verified against the file at the reviewed ref, not read off a diff
      hunk header.
- [ ] Descriptions are 1–2 sentences naming the shape and its cost — not a restatement of the
      title, not a lecture on the principle.
- [ ] Every Suggestion is one line, concrete, and uses the repo's real identifiers and paths.
- [ ] Every `Improving` value is one of the six labels, exactly one per finding.
- [ ] Duplicate reports of one shape are merged into a single finding.

## Severity and verdict

- [ ] Each label was checked against the anchor table, not assigned by feel. In particular: HIGH
      is reserved for shared business rules, layer-wide convention breaks, and per-request or
      per-row costs.
- [ ] No exported-symbol rename is rated LOW.
- [ ] The severity counts in the verdict match the findings list.
- [ ] The arithmetic is shown and correct, and the score is floored at 0.
- [ ] The band's wording matches the score, and the shortlist contains every HIGH and nothing
      else.

## Conduct

- [ ] Both preconditions were satisfied in step 1: the plan was read, and the code review was
      confirmed finished (or the user's decision to proceed anyway is noted in the handoff).
- [ ] No file was edited or created, no test suite or formatter run, nothing posted to GitHub.
- [ ] Next steps (applying the refactors, re-reviewing, posting to the PR) are offered, not
      performed.
