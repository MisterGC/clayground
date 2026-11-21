# Teaching with a lab — what makes a lesson explain

`lab-check` proves that a teaching lab is built: a flow that finishes,
`expect`s that hold, a step the learner acts on, EN and DE keys in
parity, narration lines within 240 characters and none typed into the
QML, a storyboard. It cannot tell whether the flow explains anything. A lab can pass every rule and
still only narrate: parts appear, a voice names them, a number is read
out, the learner clicks once. This file is what an author reads before
writing a lesson, and goes through again before handing one over.

The mechanics are elsewhere: step kinds, `task`/`watch`/`expect`,
pacing and narration keys in `flows.md`; the teaching paper and the
storyboard in `triad.md`. Here: what to put into those mechanisms.

Each rule below says first whether a program tests it. **Checked**
names the `lab-check` line that fails when the rule is broken
(`check-failures.md` says what to do about it); **judgement** means no
program does, and the checklist at the end is where you hold yourself
to it. Then **Do**, **Avoid** and an **Example** from a lab in
this repository. Most examples are the shipped text as it stands, quoted
by file and line, because the labs were written before these rules;
where a shipped line breaks a rule, the example says so and gives the
rewrite.

## 1. A term is defined before it is used

*Judgement — no program checks this.*

The learner's vocabulary is what the lesson has said so far, plus
everyday words. A technical word that has not been introduced is noise;
a learner who misses one word stops following the sentence.

- **Do:** introduce a term at the moment its thing is on screen, in the
  same sentence that shows what it means — the word last, after the
  meaning. Then use it, unchanged, from there on.
- **Avoid:** a term that first appears inside an explanation that
  depends on it; a term defined only in `paper.md` or on the board; an
  abbreviation (NAND, VCC) the learner has not seen spelled out.
- **Example (do):** `labs/electronics-101/strings.js:115` — "It only
  conducts one way — and only above about 2 volts, its forward voltage."
  The meaning comes first, the name after it.
- **Example (avoid):** `labs/hydraulics-101/strings.js:41` — "Add the
  pressure drops round the loop: they sum to the pump's head." *Head*
  appears here for the first time; the pump step (`:33`) called it "a
  pressure difference". Either the pump step says "a pressure difference
  — its head — of 40 kPa", or this line says "the pump's 40 kPa".
  Likewise `electronics-101/strings.js:139` ("the NAND node") relies on
  NAND, which `:136` names in passing and never spells out as "not AND".

## 2. One idea per step

*Checked in part — `teaching: every narration line fits in 240
characters` fails a line over 240 characters, in any language, a
script's `*cues*` not counted. Whether a shorter line holds one idea is
judgement.*

A step is one beat: one thing shown, one sentence that says what it
means. The learner can hold one new idea while looking at the scene;
the second one in the same step overwrites the first.

- **Do:** split a step when its narration has two claims a learner could
  get wrong separately. Keep a step at 240 characters or fewer
  (`flows.md`); a longer one usually holds two ideas.
- **Avoid:** a step that names a part, gives its value, states a rule
  and draws a conclusion in one breath; "and one more thing" at the end
  of a line.
- **Example (do):** the LED lesson's `battery`, `led` and `resistor`
  steps (`electronics-101/Sandbox.qml:1986`–`2001`) put one part on the
  board each, with one sentence about what that part does.
- **Example (avoid):** the `gain` step of `logic-gates` as it first
  shipped (it has been split since, and `lab-check` now fails a line
  that long): the base current against the lamp current, the ratio, the
  transistor's hundredfold limit, the green ring meaning saturation, and
  the lamp becoming the limit — five ideas, about 345 characters. Rewrite as
  three steps: the two readings and their ratio; "it could pass a hundred
  times — the lamp asks for only twelve"; the green ring.

## 3. Predict, then observe, then explain

*Judgement — no program checks this.*

A number the learner did not expect is the only number they remember.
Ask for the expectation before the scene answers, let the scene answer,
then explain the gap. Telling the result first and showing it after
turns the observation into a confirmation nobody needed.

- **Do:** a step that asks the question and commits the learner ("What
  happens to the current if the resistor is halved? Decide, then go on.")
  — a `task` whose `until` is the learner's choice where the lab can
  take one, a narrated question with `pacing: "ready"` where it cannot;
  then a `demo` or `watch` step that shows it; then the explanation, with
  the measured value.
- **Avoid:** narration that states the outcome in the same step that
  produces it; an explanation step before the observation step.
- **Example (do, in part):** the LED lesson observes (`lit`, "5.1
  milliamps flow, and the LED glows", `strings.js:120`) before it
  explains (`why`, `:121`). The prediction is missing: a step before
  `flip` that asks "how much current will flow — all the cell can give,
  or a little?" makes `lit` an answer.
- **Example (avoid):** `electronics-101/strings.js:139`, the `both`
  step: "the lamp goes out" is said by the demo that switches the second
  input on. The learner who just built the OR pair expects the lamp to
  stay lit — that is the moment to ask, not to tell.

## 4. A learner task that needs more than a click

*Checked in part — `teaching: <flow> has a learner task and an expect`
fails a flow with no `task` step at all (a question the lab takes an
answer to and a `"wiring": true` task count). Whether the task needs more
than a click is judgement.*

A task teaches when doing it takes the idea the lesson just gave. A
task that is one click on the part the narration pointed at tests
whether the learner can click.

- **Do:** an `until` on an outcome the learner has to work out the way
  to — a state, never a click (`flows.md`) — with `allow` lending every
  part that could reach it, so a wrong attempt is possible and visible.
  A wiring task, a value to hit, a condition to make true.
- **Avoid:** "Your turn: click the switch"; a task whose narration
  spells out the action, so the only work left is finding the button; a
  hint that gives the answer instead of a direction.
- **Example (avoid):** `electronics-101/Sandbox.qml:2015`, the `flip`
  task — one part allowed, one click, the narration says which
  (`strings.js:118`). The `wire` step before it (`:2002`) is the real
  lesson ("current needs a closed ring") and is done by the demo. Make
  `wire` the task: the four parts placed, `until` the loop is closed
  (current through the LED > 0), `allow` all four.
- **Example (do):** `Sandbox.qml:2113`, `xortask` — `until` is "the
  table stands on row 1 or row 2", which either input satisfies, and
  getting there needs the idea "exactly one".

## 5. A check for understanding

*Judgement — except its `expect`: a flow with none fails `teaching:
<flow> has a learner task and an expect`, and one that no longer holds
fails `flows: <flow>`.*

Somewhere before the end the lesson asks for the idea, not the
procedure: the learner has to apply what was said to a case the lesson
did not show, and the lab can tell whether they did.

- **Do:** phrase the task as the outcome, not the steps ("make the lamp
  light", not "turn exactly one input on"); make the wrong answer
  reachable and answer it (`Flow.refuse()` or a hint that names the
  misconception). Back it with an `expect` so the check itself cannot
  drift.
- **Avoid:** a "check" that repeats the narration's instruction word for
  word; a hint that hands over the answer ("Either switch on its own
  will do.", `electronics-101/strings.js:138`) before the learner has
  tried.
- **Example (rewrite):** `strings.js:137` says "Turn exactly one input
  on." — the definition of XOR read back as an instruction. As a check:
  "Make the lamp light." with the same `until` (`Sandbox.qml:2115`); a
  learner who switches both on sees the lamp stay dark and has learned
  the one thing XOR is about. The hint becomes "Two inputs on was the AND
  row. What did XOR refuse?"

## 6. A closing task that transfers the idea

*Judgement — no program checks this.*

The lesson ends with the learner using the idea on something it did not
build for them — and a lab that says when they got there.

- **Do:** a final `task` whose `until` needs the rule in a new
  situation ("build two bulbs in parallel; I'll tell you when the
  currents split", `flows.md`); then hand the whole board over.
- **Avoid:** ending on a demo or a "try it yourself" with no task —
  the lesson stops talking and nobody knows whether it landed; a closing
  task any change satisfies.
- **Example (avoid):** `labs/hydraulics-101/Sandbox.qml:770`, the `try`
  step — a demo that selects the pipe, no task, and the flow ends.
- **Example (partial):** `electronics-101/Sandbox.qml:2037`, the LED
  lesson's `try` — a task, which is right, but `until` is "the
  resistance is not 470 Ω" (`:2040`), so any drag ends it. Transfer is
  "set the resistor so the LED draws 10 mA" (`until` the LED current is
  within 0.5 mA of 10): the learner has to run `why`'s arithmetic
  backwards.

## 7. Scenarios chosen as a progression

*Judgement — no program checks this.*

The scenario set is the lesson's spine. Each preset adds one thing to
the one before it, in an order a learner can climb; the `1..9` keys
read as a syllabus.

- **Do:** order scenarios by what they presuppose; give each a
  `scenario.note.*` that says what is new in it; let a flow walk the
  same order (`["scenario", …]` in its demos).
- **Avoid:** a scenario list that is a parts catalogue; two presets that
  differ in two things at once; a flow that jumps backwards in the set.
- **Example (do):** `electronics-101/strings.js:12`–`22` — LED basics,
  series, parallel, metering, transistor, diode OR, AND, OR, XOR, the
  gate package, half adder. The `logic-gates` flow climbs the second
  half of it in order, and its `and` and `or` steps say what they reuse:
  "the series circuit again" (`:132`), "the parallel circuit, doing
  logic" (`:135`).

## 8. One word per thing across narration, paper and board

*Judgement — no program checks this.*

A learner who hears "cell", reads "Battery" on the palette and sees
"battery" on the board has three things to reconcile and no way to know
they are one. Pick one word per thing and use it in the narration, the
UI copy, `paper.md`, `overview.grafli` and the voice clips.

- **Do:** take the noun from the kit's `strings.js` (`part.*`) and use
  that noun in the lab. If the lesson needs a different word, change the
  kit's word, not one lab's line. A second word is introduced once, as a
  synonym ("a battery — a cell, to be exact"), and then not used.
- **Avoid:** elegant variation — "the bulb", "the lamp", "the light"
  for one part; a code name (`BAT`) in narration.
- **Example (avoid):** the circuit kit calls the parts "Battery" and
  "Bulb" (`labs/kits/circuit/strings.js:10`, `:14`), and so does the
  board (`electronics-101/overview.grafli:15`); the narration says "the
  cell" (`strings.js:114`) and "the lamp" (`:131`, `:139`). German keeps
  "Lampe" throughout but says "Zelle" for the part its palette calls
  "Batterie". Same in hydraulics-101: EN "narrow pipe" (`strings.js:35`),
  DE "Drossel" in one sentence and "Engeres Rohr" in the next (`:76`).

## The German

German is a second lesson, not a second column. A translation that
follows the English word for word reads as a translation and teaches
worse.

*Judgement, all four — `lab-check` checks only that German exists, with
the same keys as English (`strings: …`), and that its lines fit in 240
characters.*

- **A word list per kit.** The kit's `README.md` carries a *Words*
  table — EN term, DE term, and the words not to use for it — beside the
  part names in the kit's `strings.js`. A lab uses those words and adds
  its own lab-only terms to its own list. A term with no entry is
  decided once, written in, and then used.
- **No word-for-word translation.** Translate the sentence's job, not
  its words: German builds the sentence around the verb at the end,
  takes the technical word school teaches ("Durchlassspannung",
  `electronics-101/strings.js:252`), and does not carry over English
  images that do not exist in German. `:277`, "Das ist es, was dieses
  Bauteil erkauft hat", is "That is what this part bought" with German
  words; a German teacher says "So viel Aufwand steckt in diesem einen
  Bauteil."
- **Read it through as a German reader.** After writing, read the whole
  flow in German in one go, in the lab (`LabLang.lang = "de"`), without
  the English beside it. Every sentence that makes you think of the
  English one is rewritten. Check the narration against the panels: the
  German is ~25 % longer and must still fit (`SKILL.md`, *Design rules*).
- `du`, not `Sie`; units with a comma decimal through `LabLang.num` /
  `LabLang.qty`, never typed.

## Narration audio

Narration is text first; a clip is a recording of a line, never the
source of it. How the electronics clips are made is
`labs/electronics-101/voice/README.md`; this is the general rule.

*Judgement, every rule here — a clip is not loaded by `lab-check`, and a
missing one is never an error. That the text comes first is checked:
`teaching: no narration is written in the QML` fails a step whose line is
a `say` literal instead of a `strings.js` key.*

- **How a clip is made.** Offline, on the author's machine, with the
  local text-to-speech tool at `~/dev/eval/local_tts` (one line per
  invocation, a fixed `--seed` so a render can be repeated, then
  `afconvert` to 48 kbps AAC `.m4a`). Only the `.m4a` is committed; the
  `.wav` master stays local. Nothing is synthesised at runtime. Never
  play a clip to check it from an agent session — render it to a file.
- **The spoken form is its own text.** Units are read out ("milliamps",
  "ohms"), dashes become commas, anything written for the eye is
  rewritten for the ear. The exact spoken text of every clip is listed in
  the lab's `voice/README.md`, by clip name.
- **Naming ties a clip to its line**: one clip per narrated step
  (`voice/<lang>/<step>.m4a`), one per spoken line of a directed step
  (`<step>-<n>.m4a`, `n` counting the script's say cues from 0). The lab
  resolves the file from the step key (`flowVoice`,
  `electronics-101/Sandbox.qml:1378`); a step with no clip is narrated as
  text, so a missing clip is never an error.
- **Kept in step with the text.** A change to a narrated line in
  `strings.js` — or in a directed step's script (`ledScripts`,
  `Sandbox.qml:1403`) — renders that line's clip again and updates its
  entry in `voice/README.md` in the same commit. When the tool cannot
  run, delete the stale clip so the line falls back to text; a clip that
  says something the screen does not is worse than none. The PR lists
  every new or changed clip by name, because a clip is judged by ear.
- The three copies of one line — `strings.js`, the script, the
  README's spoken form — are compared by eye today and already differ:
  `strings.js:114` says "the gold one is plus", the `battery` script and
  its clip say "The gold pad is the plus side". When you touch a line,
  make the three agree.

## Before handing a lab over

Go through this with the lab running and the flow played once in each
language, start to end, as a learner would. A box marked *(checked)* is
one `lab-check` fails on its own; tick it from the green run. Every other
box is judgement.

- [ ] Every technical word is introduced on screen before it is used,
      and the lesson never relies on the paper for a definition.
- [ ] No step carries two ideas; no narration runs past 240 characters
      *(the 240: checked)*.
- [ ] At least one result is predicted by the learner before the lab
      shows it, and explained after.
- [ ] Every flow has a `task` *(checked)*; every `task` needs the
      lesson's idea to complete, and at least one needs more than a
      single click; hints point, they do not answer.
- [ ] One task checks understanding: phrased as an outcome, with a
      reachable wrong answer that the lab answers, backed by an `expect`
      *(an expect in every flow: checked)*.
- [ ] The flow ends on a transfer task, then hands the board over.
- [ ] The scenarios climb: each adds one thing, and the flow walks them
      in order.
- [ ] One word per thing in narration, UI, kit, paper, board and clips,
      in each language, matching the kit's word list.
- [ ] The German was read through on its own, in the lab, and nothing in
      it reads as translated.
- [ ] Every line is a `strings.js` key, none a `say` literal
      *(checked)*; every clip matches its line's spoken form in
      `voice/README.md`; changed lines have new clips or none; the PR
      lists them.
- [ ] `lab-check labs/<slug>` is green *(checked)* — last, because it
      checks the structure and the boxes marked checked, not the rest of
      this list.
