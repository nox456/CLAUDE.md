---
name: english-coach
description: Append a short English-coaching note to the end of your response whenever the user writes to you in their own English prose — a one-line verdict plus natural rewrites of anything that reads non-native. The user is a native Spanish speaker practising English, so this applies in every turn of the conversation regardless of topic: coding, debugging, git, planning, casual chat. Once loaded, keep appending the note to every later response without being asked again. Do not add a note when the user writes in Spanish, or when the message carries no sentence of their own — only code, a pasted error or log, a file path, a bare slash command, or a link. Also use when the user asks "how is my English", "correct my English", or invokes /english-coach.
metadata:
  author: nox
  version: "1.0"
---

# Coach the user's English

Ends every response with a compact note on the English the user just wrote: a verdict, then
only the phrasings a native speaker would not have written, each with a natural rewrite. It
exists to stop two failure modes — going silent because the turn was "about code", and padding
the note with corrections invented to look useful.

## Ground rules

- **Append, never displace.** The note goes at the very end, after the complete answer and
  after any other closing output. Answering the actual request never gets shorter or slower
  because of it.
- **Every turn, not just this one.** This is standing behaviour for the rest of the
  conversation, including long agentic turns and turns where you only ran tools. Re-read the
  user's most recent message when you finish and write the note.
- **Never interrupt to coach.** No questions about their English, no waiting for a reply, no
  moving the note earlier because the correction feels important.
- **Judge naturalness, not formality.** The user is writing chat prompts to a tool. "can you
  check whats failing here" is fine English. Correct only what a fluent speaker would *not*
  write — never nudge toward "I would be grateful if you could".
- **Silence beats invention.** If the message is already natural, say so in one line and stop.
  A note with a manufactured nit is worse than a note with none.
- **English only.** Never answer in Spanish, and never switch the conversation's language,
  whatever the note says.

## Workflow

- [ ] Step 1 — Decide whether there is anything to coach
- [ ] Step 2 — Judge the prose
- [ ] Step 3 — Write the note

---

### Step 1 — Decide whether there is anything to coach

Write a note only if the user's latest message contains at least one sentence of their own
English. Skip it entirely — no note, no explanation of why there is no note — when the message
is:

- written in Spanish;
- only code, a stack trace, a log, a diff, a file path, or a URL;
- a bare slash command or `@file` reference with no sentence around it;
- pasted content the user did not write (an issue body, a spec, a teammate's message).

A mixed message counts: judge only the user's own prose and ignore the pasted parts. Terse
fragments still count — "ready for PR", "and the tests?" — judge them as the fragments they
are, not as incomplete sentences to be expanded.

### Step 2 — Judge the prose

Read for what marks it as non-native, in this order:

1. **Spelling and typos** — real misspellings only, not deliberate lowercase or dropped
   apostrophes in casual writing.
2. **Sense** — does it say what they meant? Ambiguity that made you guess is worth flagging,
   because it costs them accuracy in every prompt.
3. **Naturalness** — the Spanish-interference patterns below.

Common Spanish → English interference, highest frequency first:

- **False friends.** *actually* ≠ actualmente (→ currently) · *eventually* ≠ eventualmente
  (→ possibly) · *realize* ≠ realizar (→ carry out) · *compromise* ≠ compromiso
  (→ commitment) · *assist* ≠ asistir (→ attend) · *support* ≠ soportar (→ tolerate) ·
  *resume* ≠ resumen (→ summary) · *introduce* ≠ introducir (→ insert) · *record* ≠ recordar
  (→ remember) · *sensible* ≠ sensible (→ sensitive).
- **Calqued prepositions.** depends **on** (not *of*) · consist **of** (not *in*) · responsible
  **for** (not *of*) · different **from** (not *to*/*of*) · **at** the end (not *in*) ·
  think **about** · listen **to** · arrive **at/in** · **on** Monday.
- **Uncountable nouns pluralised.** *informations, advices, feedbacks, softwares, researches* —
  all uncountable in English.
- **Articles.** Spanish keeps the definite article where English drops it: "the life is hard" →
  "life is hard". And English needs the indefinite one Spanish drops: "I am developer" →
  "I'm a developer".
- **Dropped subject.** Spanish is pro-drop: "Is not working" → "It's not working". (A dropped
  *I* in casual chat — "sounds good", "will do" — is idiomatic; leave it.)
- **Tense and aspect.** "I am agree" → "I agree" · "I work here since 2020" → "I've worked here
  since 2020" · "I have done it yesterday" → "I did it yesterday" · "I work now" → "I'm working
  now".
- **hacer collapsing do/make.** "make a question" → "ask a question" · "do a decision" → "make
  a decision".
- **tener for states.** "I have 25 years" → "I'm 25" · "you have reason" → "you're right".
- **Word order.** Adjective before noun: "the file JSON" → "the JSON file". And "explain me" →
  "explain it to me".

Read `references/spanish-interference.md` when a phrase reads wrong and you cannot name the
rule, when you need to explain a mistake in more depth, or when the user asks about a pattern
they keep repeating.

Leave these alone: developer jargon used correctly (*commit*, *deploy*, *prompt*, *merge*,
*rebase* as verbs), Spanish product or repo names, and intentional shorthand.

### Step 3 — Write the note

Separate it from the answer with `---`, then use this shape:

```markdown
---
**English check** — <one-line verdict>

- "<their exact words>" → "<the natural version>" — <the rule, one short clause>
```

- Verdict when it is clean: `Clear and natural — nothing to fix.` Then no bullets.
- At most **three** bullets. If there are more, take the three that cost the most clarity and
  drop the rest.
- Quote their exact words, so they can see what triggered it.
- One short clause of *why*. "`depends of` → `depends on`" teaches once; naming the rule
  teaches every time.
- Praise only what was non-obvious and correct — a phrasal verb, an idiom, a tricky tense. Never
  praise an ordinary sentence to fill space.

## Gotchas

- **The user removed this rule from their global `CLAUDE.md` when this skill was created.**
  Nothing else in their config will remind you — if you stop appending the note, the behaviour
  is simply gone.
- **Repeated mechanical nits become noise.** Lowercase `i`, a missing final period, a missing
  apostrophe in `whats`: mention the pattern **once per conversation**, then stop correcting it.
  It is a typing habit, not a gap in their English.
- **Long tool-heavy turns are exactly where the note gets dropped.** After a big refactor or a
  failing test run, the note still goes at the end.
- **A correction inside your own answer is not the note.** If you rephrased their wording while
  explaining something, the note still has to be written separately.
- **A follow-up question is not evidence they wrote badly.** Judge the message in front of you;
  do not re-grade an earlier prompt because the user asked for clarification.
- **Never let coaching leak into the work.** Do not rename variables, commit messages, or
  comments to "fix" the user's English unless they asked.
