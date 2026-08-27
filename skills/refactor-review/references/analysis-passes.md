# The four analysis passes

Read at the start of step 3, before writing any finding. The thresholds here are the point of
this reference — apply them literally rather than by feel, because "could be cleaner" is true of
all code and is not a finding.

## Before you write any finding: the behavior check

Every finding is a claim that the code can be written differently **and do exactly the same
thing**. Prove it the cheap way, in this order:

1. State in one sentence what the code does now, and what it does after your Suggestion. If the
   two sentences differ in *any* observable way, drop the finding.
2. Watch for the four that look behavior-preserving and are not:
   - **Extracting code that closes over mutable state** — the copy loses the binding.
   - **Deduplicating two blocks that differ in one literal** — check every literal, especially
     error messages, keys, and units. If they differ, the "duplicate" is two behaviors.
   - **Reordering statements** — anything with a side effect, a throw, or an early return
     between them changes the outcome on the failure path.
   - **Replacing a loop with a built-in** — `find`/`some`/`map` change short-circuit timing and
     what happens on an empty collection.
3. `rg` the symbol for every caller before proposing a signature or name change. The blast
   radius belongs in the Description.
4. Check `git log -S'<symbol>'` when the code looks deliberately clumsy. Odd-looking code often
   encodes a fix you are about to undo.

## Pass 1 — Duplication and reuse

Find the copies the change introduced, then decide with the table — do not extract on instinct.

| The duplicate | Report? |
| --- | --- |
| ≤5 lines, 2 copies | **No.** This is the "don't overwhelm" case. Leave it |
| ≤5 lines, 3 or more copies | Yes, LOW — and only if the copies must change together |
| More than 5 lines, 2 or more copies | Yes, MEDIUM |
| Any size, if the copies encode **one business rule** | Yes, HIGH — regardless of length |

The last row overrides the size rule and is the one that matters. A 2-line duplicated tax rate,
status→label map, permission list, validation regex, rounding rule, or retry policy is worse
than 20 duplicated lines of boilerplate, because the copies *must* change together and nothing
makes them.

**The trap: coincidental duplication.** Two blocks that look identical today but change for
different reasons must stay separate. Before proposing an extraction, ask what would happen if
one caller's requirement changed — if the answer is "add a flag to the shared function", the
duplication was the right design. A shared util with a boolean parameter that selects between
two behaviors is a failed extraction; withdraw the finding instead.

**Where the util goes**, in order of preference:

1. An existing util file already imported by both call sites.
2. An existing util file at the nearest shared ancestor of the call sites.
3. A new util file — only when neither of the above exists.

Check the import direction first: the target must be importable by every call site without
creating a package cycle. Name the concrete path in the Suggestion; "extract to a shared util"
with no destination is not actionable.

## Pass 2 — Module shape and util placement

**First-class module**: a file whose job is a primary unit of the app — a route or controller, a
service, a React component, a hook, a job or worker, a store, a repository. A file that is
*already* a util/helper/lib file is not one, and is exempt from this pass.

**Util function definition**, for counting purposes: a function defined in that file that
- does not close over the module's state or its component/hook scope, and
- would still make sense on its own, given only its arguments.

That excludes event handlers, a component's render helpers, functions that read module-level
mutable state, and anything that captures a closure variable. Counting those inflates the number
and produces a finding that cannot actually be acted on.

**The rule:** more than 3 such definitions in one first-class module → **one** MEDIUM finding for
the file, `Improving: Modularity`. Not one finding per function. Name the target util file
(reuse before create, using the preference order from pass 1) and list the functions to move.

At exactly 3 or fewer, there is no finding — even if they would read better elsewhere.

## Pass 3 — Repo conventions

The repo is the standard here, not general style. Every finding in this pass cites its evidence,
and the citation goes in the Description:

- a line in `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or a style guide, **or**
- **two or more** sibling files in the same layer doing it the other way.

One sibling file is not a convention. If you cannot cite either, you have a preference — drop it.

What to check, against the baseline gathered in step 2:

- **Variable and function naming** — the casing and the vocabulary this layer uses. Does it say
  `fetchX`/`getX`/`loadX`? `isX`/`hasX` for booleans? Are handlers `handleX` or `onX`?
- **File and directory naming** — kebab vs. camel vs. Pascal, `.service.ts`-style suffixes,
  `index` re-export style, test file placement and naming.
- **Design patterns already in use** — how this layer does dependency injection, error handling
  (thrown vs. returned results), validation, data access, DTO mapping, state management. A
  change that introduces a second pattern for a job the repo already has one for is the
  highest-value finding in this pass: it is what teaches the next author the wrong thing.
- **Import and export style** — barrel files, relative vs. alias paths, default vs. named
  exports, import ordering when it is enforced.

Consistency is the goal, not correctness in the abstract. If the change follows a repo
convention you personally would not have chosen, that is not a finding.

## Pass 4 — Readability and cost

**Report** when the code is hard to follow as written, and you can name *what* is hard:

- Nesting depth that hides the main path — the fix is usually a guard clause or early return.
- A function doing several unrelated jobs, where the split points are already visible in the
  body (validation, then work, then formatting).
- Unexplained literals — a magic number, a bare string key, a duration in milliseconds — where a
  named constant would carry the meaning.
- A name that lies or says nothing: `data`, `result`, `handle`, `tmp`, a boolean named for the
  false case, a plural holding one item.
- Boolean-parameter call sites (`render(true, false)`) where an options object or two functions
  would read.
- **Dead code**: unreachable branches, commented-out code, exports nothing imports (`rg` the
  symbol before claiming it), leftovers from an approach the plan says was abandoned.

**Never report**, no matter how much shorter it would be:

- Collapsing an `if`/`else` chain into nested or chained ternaries.
- Point-free or heavily chained one-liners replacing a readable loop.
- Extracting a 2-line helper used exactly once.
- Shortening a clear name to an abbreviation.
- Comment removal. A comment explaining *why* is the highest-value line in a file.
- Anything whose whole justification is the line count.

**Performance**, only in its structural, behavior-preserving forms — and only when you can name
the cost:

- Work inside a loop that is invariant across iterations (a compiled regex, a lookup, a config
  read).
- A per-item query or request where a batched call already exists on the same client (N+1).
- A nested scan over a collection with no bound, where a `Map` built once gives the same result.
- Recomputing on every render or every call something the surrounding code already memoizes by
  convention.

Micro-optimizations, loop-style swaps, and anything you would have to measure to defend are not
findings. If the rewrite changes the result for any input — including empty, duplicate keys, or
ordering — it fails the behavior check and is dropped.
