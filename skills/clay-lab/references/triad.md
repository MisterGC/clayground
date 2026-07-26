# The lab–paper–board triad

Each finished lab ships three artifacts, one per reading mode:

| Artifact | Mode it serves |
|---|---|
| the lab (dojo / WASM) | immersion — stand inside the system and push on it |
| `paper.md` (textli) | depth — the model, its equations, its limits, measured results |
| `overview.grafli` (grafli) | overview — concept topology, deep-linked into the paper |

The triad is conventions plus skill knowledge, **never runtime
dependencies** — the lab never links against textli or grafli. If the
`textli` and `grafli` skills are available, load them before authoring
the respective artifact; their conventions govern format details. This
file covers what is lab-specific.

Write the paper and board **last**, from measured numbers. The paper is
not documentation-after-the-fact in spirit — writing it is what forces
the numbers to be right — but its results section can only be written
after the verification runs exist.

## Purpose decides the structure

Ask what the lab is *for* before writing a line of either artifact, and
say so in the paper's opening. The three purposes want genuinely
different documents, and a paper written for the wrong one reads as
padding — a lesson plan full of uncertainty budgets, or a lab report
that keeps stopping to ask the reader a question.

| Purpose | Who reads it | `paper.md` is | `overview.grafli` is |
|---|---|---|---|
| **learning** | you, working it out | a study path | a concept map that grows |
| **teaching** | someone you are explaining it to | a lesson plan | a storyboard of reveals |
| **research** | you or a reviewer, later | a lab report | a model diagram |

### learning — the lab is your study space

1. **The question** and, before any answer, **what you expected** —
   writing the wrong prediction down is the whole point.
2. **The model at the level you can currently hold**, not the textbook's.
3. **Worked examples you can redo in the lab** — each one a scenario,
   a knob to turn, and the number to watch.
4. **Where the intuition broke** — the surprises, in your own words.
5. **Still open** — the questions the lab did not settle.

The board grows with the understanding: prerequisite → concept →
consequence, with unresolved nodes explicitly marked as questions rather
than quietly omitted. The distinguishing move is that the misconceptions
you actually hit get recorded, because that is the one thing you cannot
reconstruct later.

### teaching — someone else is the reader

1. **The misconception it targets**, stated as the belief a learner
   arrives with.
2. **The demonstration sequence** — which scenario, what to change, what
   to ask, in order.
3. **The moment the number contradicts the belief** — name the reading
   and the value it lands on.
4. **The takeaway**, in one sentence a learner could repeat.
5. **When they ask…** — the two or three follow-ups that always come,
   with answers.

The board is a storyboard: one node per beat, in reveal order, mirroring
the guided flow exactly. Here the **flow is the primary artifact** and
the paper is its script, so prepared scenarios matter more than a wide
parameter range — the reader is on rails on purpose.

### research — the lab is an instrument

1. **The question**, sharp enough to be answered by a number.
2. **Method** — what is swept, what is held, how many runs.
3. **The model and its assumptions**, with each simplification's
   expected effect on the result.
4. **Results** — the table, with seed, scenario, step count and
   uncertainty, and one sentence on reproducing it.
5. **Limitations** — where the answer stops being trustworthy.

The board is a model diagram: what feeds what, where each assumption
sits, which quantities are measured and which derived. Determinism and
CSV export are load-bearing rather than nice to have, and the staleness
contract below bites hardest here.

### When the purpose shifts

A lab often starts as research and becomes teaching once you know the
answer. When that happens, **re-cut the paper rather than appending to
it** — a lab report with a lesson plan bolted on the end serves neither
reader, and the flow it needs is a different flow.

## paper.md

Whatever the purpose, these hold. Structure that has worked (see
`labs/electronics-101/paper.md` and `labs/sensor-fusion-101/paper.md`,
both teaching labs):

1. **The hook** — what question the lab answers, in two sentences.
2. **The model** — the actual math in pandoc-math notation (the Kalman
   update, the nodal equations), at the level implemented, not the
   textbook level.
3. **Stated simplifications** — labs teach concepts; simplified models
   are a *feature* provided each one is declared (constant-resistance
   bulb, DC-only, kinematic traffic). Every simplification a learner
   could trip over in-app belongs here AND in the app.
4. **Measured results** — a table of numbers from real runs, with the
   seed, scenario, and step count that produced them, and one sentence
   on how to reproduce ("seed 42, `open-sky`, 3600 steps").
5. **How to run + key map** — must list *every* handled key, including
   the flow keys (`T`, `Space`).
6. **Source map** — `path:line` references into the lab source (textli
   makes them followable).

### The staleness contract — the one rule that matters most

**A paper that quotes numbers the code cannot reproduce is worse than no
paper.** The papers advertise reproducibility; readers will verify.
Therefore:

- Every number in the results table comes from a run of the *current*
  code, never from memory or estimation.
- Any change to the model, sensors, RNG consumption pattern, or
  measurement weighting **invalidates the results table** — re-measure
  before shipping the change, or mark the section stale in the same
  commit.
- Source-map line numbers drift with every edit — re-check them as the
  last step before handover.
- The paper, the board, the hint bar and the flow narration must agree
  on key bindings and on what things are called. (A board that says "R
  records CSV" when `R` rotates and `Shift+R` records sends a learner
  destroying their layout.)

## overview.grafli

- Concept topology, not a screenshot: the causal chain of the lab
  (build → solve → show; sensors → filter → estimate), with deep links
  into the paper's sections. Which topology depends on the purpose — a
  growing concept map, a reveal storyboard or a model diagram; see
  *Purpose decides the structure* above.
- Its guided flow (bookmarks) mirrors the in-lab flow — same order, same
  vocabulary.
- Include the key map and the scenario list; keep every binding claim in
  sync with the code (same staleness contract as the paper).
- Numbers on the board are measured numbers, same provenance rule.
- The paper-and-ink `LabTheme` *is* grafli's design DNA — a board and
  its lab should look like siblings without extra effort.

## strings.js

Not strictly a triad member but shipped alongside from the first
commit: `{ en: {key: text}, de: {key: text} }` exported as `dict`. The
kit owns part vocabulary in its own `strings.js`; the lab owns UI copy
and flow narration; the lab may override kit keys. No bare user-visible
literal in any QML file.

## Feedback loop

CriticMarkup remarks in `paper.md` (`{>> like this <<}`) are the
standing review channel — collect and address them on resume, same loop
as groundwork review.
