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

## paper.md

Structure that has worked (see `labs/electronics-101/paper.md` and
`labs/sensor-fusion-101/paper.md`):

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
  into the paper's sections.
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
