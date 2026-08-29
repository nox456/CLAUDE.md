# Spanish → English interference, extended

Load when a phrase reads wrong and you cannot name the rule, when the user asks *why*
something was wrong, or when they ask about a mistake they keep repeating. `SKILL.md` carries
the high-frequency subset; this file is the long tail and the explanations.

## False friends

| They write | They mean | English actually means | Use instead |
| --- | --- | --- | --- |
| actually | actualmente | in reality, in fact | currently, right now |
| eventually | eventualmente | in the end, sooner or later | possibly, occasionally |
| realize | realizar | become aware of | carry out, perform, do |
| compromise | compromiso | meet halfway, weaken | commitment, obligation |
| assist | asistir a | help | attend |
| attend | atender | be present at | serve, help, take care of |
| support | soportar | back, hold up | tolerate, put up with, withstand |
| resume | resumen | continue after a pause | summary |
| introduce | introducir | present a person/topic | insert, put in |
| record | recordar | store, register | remember, remind |
| sensible | sensible | reasonable, practical | sensitive |
| library | librería | lending collection | bookstore |
| carpet | carpeta | floor covering | folder |
| large | largo | big | long |
| exit | éxito | way out | success |
| fabric | fábrica | cloth | factory |
| advertisement | advertencia | an ad | warning |
| pretend | pretender | fake, act as if | intend, aim to |
| discuss | discutir | talk over | argue |
| resign | resignar | quit a job | accept, give in to |
| parents | parientes | mother and father | relatives |
| envy | enviar | jealousy | send |
| actual | actual | real, genuine | current, present |
| topic | tópico | subject | cliché |
| deception | decepción | deliberate lie | disappointment |
| conductor | conductor | orchestra leader | driver |

In dev contexts the ones that bite most often are **actually/currently**,
**eventually/possibly**, **realize/carry out**, **compromise/commitment**, and
**support/tolerate** — all of them produce a sentence that parses fine in English but says
something else, so they never look like errors.

## Prepositions

Spanish maps prepositions to verbs differently, and the wrong one is the single most audible
non-native marker.

| Wrong (calque) | Right | Spanish source |
| --- | --- | --- |
| depends of | depends **on** | depende de |
| consist in | consist **of** | consiste en |
| responsible of | responsible **for** | responsable de |
| different to / of | different **from** | diferente de |
| in the end of the file | **at** the end of the file | al final de |
| in Monday | **on** Monday | el lunes |
| arrive to the office | arrive **at** the office | llegar a |
| think in / think on | think **about** | pensar en |
| dream with | dream **about/of** | soñar con |
| married with | married **to** | casado con |
| worry for | worry **about** | preocuparse por |
| listen music | listen **to** music | escuchar música |
| enter to the room | enter the room (no preposition) | entrar a |
| ask **for** a question | ask a question (no preposition) | hacer una pregunta |
| discuss **about** | discuss (no preposition) | discutir sobre |
| explain me | explain **to** me | explícame |
| approach **to** the problem (verb) | approach the problem | acercarse a |

`based in` vs `based on` is a real pair, not an error: *based in* = located in a place,
*based on* = derived from something. "The decision is based in the data" is wrong; "the team
is based in Madrid" is right.

## Countability

English treats as uncountable several nouns Spanish pluralises freely. No `-s`, no `a/an`,
and they take a singular verb:

`information` · `advice` · `feedback` · `software` · `hardware` · `research` · `progress` ·
`knowledge` · `evidence` · `equipment` · `homework` · `work` (as effort) · `news` (looks
plural, takes a singular verb: "the news **is** good").

To count them, use a unit: *a piece of advice*, *two pieces of information*, *a bit of
feedback*.

`data` is genuinely split — plural in formal writing, singular in ordinary tech English
("the data is stale"). Do not correct either.

## Articles

- **Spanish adds, English drops.** Generic plurals and abstract nouns take no article:
  "the life is hard" → "life is hard"; "I like the dogs" → "I like dogs"; "the technology is
  advancing" → "technology is advancing".
- **Spanish drops, English adds.** Professions and singular countable nouns need one:
  "I am developer" → "I'm a developer"; "I have meeting" → "I have a meeting".
- **Institutions.** English drops the article after certain prepositions: "go to the work" →
  "go to work"; "in the home" → "at home"; "in the bed" → "in bed".

## Tense and aspect

- **estar de acuerdo.** "I am agree" → "I agree". *Agree* is a verb in English, not an
  adjective.
- **Present perfect with `since` / `for`.** Spanish uses the present: "I work here since
  2020" → "I've worked here since 2020"; "I know him for two years" → "I've known him for two
  years". `since` + a point in time, `for` + a duration.
- **Present perfect vs simple past.** English forbids the present perfect with a finished
  time expression: "I have done it yesterday" → "I did it yesterday".
- **Present simple vs continuous.** Spanish present covers both: "I work now" → "I'm working
  now"; "What do you do?" (job) vs "What are you doing?" (right now).
- **hace → ago / for.** "I started hace two weeks" → "two weeks ago"; "hace two weeks that I
  work here" → "I've been working here for two weeks".
- **Conditionals.** "If I would have time" → "If I had time"; "If I would have known" → "If I
  had known". No *would* in the `if` clause.
- **Subjunctive after `want`.** "I want that you review it" → "I want you to review it".

## Verb-noun collocations

`hacer` splits into several English verbs:

- **make** a decision, a mistake, a change, an effort, progress, sense, a suggestion
- **do** homework, research, a task, the dishes, an analysis, a favour
- **ask** a question · **give** a presentation · **take** a decision (BrE) or make one (AmE)

`tener` describes states English builds with *be*: "I have 25 years" → "I'm 25"; "I have
hungry/cold/sleepy" → "I'm hungry/cold/sleepy"; "you have reason" → "you're right"; "I have
fear" → "I'm afraid".

## Structure and word order

- **Adjective before noun.** "the file JSON" → "the JSON file"; "a solution temporal" → "a
  temporary solution".
- **Dropped subject.** English is not pro-drop: "Is not working" → "It's not working"; "Seems
  fine" → "It seems fine" in writing (though it is idiomatic in casual chat).
- **Dropped dummy `there`.** "In the file are three errors" → "There are three errors in the
  file".
- **Double negative.** "I don't want nothing" → "I don't want anything".
- **Questions keep auxiliary + inversion.** "Why you did that?" → "Why did you do that?"
- **`lo mismo`.** "Do the same that before" → "the same as before"; "It's the same" is fine,
  but "the same" as a stand-alone pronoun for a whole clause ("please review the same") is
  Spanish-in-English.
- **`por eso`.** "For this, I changed it" → "That's why I changed it" / "So I changed it".
- **`o sea` / `es decir`.** → "I mean", "that is", "in other words".

## Register

The user writes chat prompts, not correspondence. Direct and terse is correct English here:
"check why the build fails" needs no softening. Flag register only in the opposite direction —
when a calque from Spanish formality ("I would be grateful if you could proceed to review")
lands as stiff in a context where a native speaker would write "can you review this?".

Contractions (*it's*, *don't*, *I'll*) are standard in this register; their absence reads
formal, not correct.
