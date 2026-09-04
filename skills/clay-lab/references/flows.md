# Authoring flows — narrated, self-driving walkthroughs

A flow gives a lab a voice and a hand: it operates the lab through the
lab's own verbs, explains what it is doing, and hands control to the
learner at the right moments. Two uses, one mechanism: *tutorial* ("here
is how this lab works") and *experiment* ("here is a thing worth
understanding"). A flow that cannot be interrupted is a video, and a
video is cheaper to make — interruptibility is the point.

## The action layer: one mutation API, three drivers

Every state change the lab supports is a named verb in `flowActions()`.
The lab's own UI calls those verbs, a flow calls the same verbs, and an
agent calls them through `eval`. No verb exists that only a flow can
perform; no UI path mutates state behind the API's back.

```qml
function flowActions() {
    return {
        "addPart":    (type, col, row) => addElement(type, col, row),
        "wire":       (a, ta, b, tb)   => addWire([a, ta], [b, tb]),
        "flipSwitch": (id)             => toggleSwitch(id),
        "watch":      (id, on)         => setWatched(id, on),
        "select":     (id)             => { selectedId = id },
        "frame":      (what)           => what === "selection"
                                          ? frameSelection() : frameSetup(),
        "scenario":   (n)              => applyScenario(n),
        "setParam":   (n, v)           => Lab.set(n, v)
    }
}
```

Steps are **data**, not closures — that is what makes a flow diffable,
translatable, validatable and replayable. Demo entries:

- `["verb", arg1, arg2]` — invoke a verb.
- `["let", "name", "verb", ...args]` — invoke a verb and bind its return
  value to a flow-local name. Steps address objects by these names
  (`"bat"`), never by numeric ids (allocation order changes when the
  scene is edited). Inside predicates the lookup function `n` resolves
  them: `(n) => root.elemAt(n("led"))`.

## Step anatomy

```qml
Flow {
    id: ledFlow
    lab: root                       // the sandbox root (verb + name source)
    flowId: "led-basics"            // kebab-case, stable: it is a key prefix
    titleKey: "flow.led-basics.title"

    FlowStep {
        key: "battery"              // narration key suffix, stable
        demo: [["let", "bat", "addPart", "battery", 6, 2],
               ["select", "bat"], ["frame", "selection"]]
    }
    FlowStep {
        key: "flip"                 // the learner acts
        task: ({ "until": (n) => { const e = root.elemAt(n("sw")); return e && e.on },
                 "hint": "flow.led-basics.flip.hint",
                 "hintAfter": 7,    // sim seconds until the hint shows
                 "solve": [["flipSwitch", "sw"]] })   // the "show me" path
    }
    FlowStep {
        key: "lit"
        demo: [["watch", "led", true]]
        expect: (n) => Math.abs(root.simOf(n("led")).i - 0.00515) < 5e-5
    }
    FlowStep {
        key: "tunnel"               // the SIMULATION acts
        demo: [["scenario", "tunnel"]]
        watch: ({ "until": () => root.carInTunnel })
    }
}
Narrator { flow: ledFlow }          // bottom-centre; hide the hint bar
                                    // while ledFlow.running
```

Three step kinds, by who acts:

- **demo** — the lab acts through its verbs; the learner watches.
- **task** — the learner acts; `until` is a predicate on *lab state*
  ("the LED is lit"), never on a specific click, so there is always more
  than one way to satisfy it. Escalation, all optional: narration →
  after `hintAfter` sim-seconds the hint shows → *show me* runs `solve`.
  Nobody is ever stuck.
- **watch** — the *simulation* acts; the step ends when the world
  reaches the moment worth explaining. The narrator says "watching…"
  instead of "your turn"; interruption there counts as taking over,
  while acting during a task counts as participating (`takeOver()` is a
  no-op while `waiting`).

A step with none of the three just narrates.

## Rules that make a flow teach

- **A flow never locks the lab.** Input mid-flow pauses it (wire your
  interaction handlers to call `flow.takeOver()`); the narrator offers
  resume / replay / leave. No modal overlay, no disabled inputs.
- **Pacing ripens, never forces.** `pacing: "ready"` (default): a
  reading-time estimate ripens the Next control — dimmed but **always
  clickable**, never disabled. `"auto"` advances on elapse (kiosk,
  recordings, headless verification). `"manual"` shows no estimate.
  Dwell is measured in **sim seconds**, so `timeScale` scales a flow and
  headless runs traverse identical states.
- **One idea per step**; keep narration under ~240 characters.
- **Checkpoints make scrubbing cheap**: before each step the runner
  stores `viewState()` + the name table; `goTo(k)` restores checkpoint k
  and replays only step k's demo. Progress dots are clickable. In Box2D
  labs a backward jump resumes from the scenario boundary, not the exact
  frame (see pitfalls).
- **Every flow is also a test.** One command walks it:

  ```bash
  clayrender labs/<lab>/Sandbox.qml --out /tmp/x.png \
      --paused --result - --eval 'Lab.runFlow("<flowId>")'
  ```

  `Lab.runFlow()` forces `pacing: "auto"`, steps the clock at 1/60 s and
  runs each task's `solve` itself, then reports `unresolvedVerbs`,
  `failedTasks` and `failedExpects` (each with its step key) plus
  `finished`. Give the key steps `expect` predicates with the *measured*
  value — a drifted lab then breaks its own lesson loudly instead of
  teaching a wrong number. `lab_check_<lab>` (#208) runs the same call for
  every id in `flows()`, so a lesson that drifts is red in a build; the
  command above is for one flow while you are working on it.
- **End with a handoff**: explain the number the learner just produced
  ("2.4 V over 470 Ω is 5.1 mA"), then "now try it yourself" — and
  ideally a final *task* that verifies transfer ("build two bulbs in
  parallel; I'll tell you when the currents split").

## Narration and i18n

Narration lives in the lab's `strings.js` under
`flow.<flowId>.<stepKey>` (plus `.hint` suffixes), EN + DE from day one;
`titleKey` names the flow in the picker/narrator. `FlowStep.say` is an
inline fallback for prototyping only — a shipped flow has no bare `say`
literals. Switching language mid-flow re-narrates the current step for
free because narration is an ordinary `LabLang` binding.

Audience tiers: materially different paths are **separate flows** (own
`flowId`, own steps); same path with simpler words is a narration-key
suffix resolved with fallback. Don't fork physics for vocabulary.

## Discoverability — the part everyone forgets

A flow nobody finds teaches nobody. Ship all three:

- `T` starts/stops the (first) flow; `Space`/`→` next, `←` back, `Esc`
  leaves. `LabKeys` owns all of these, and `LabHelp` (`?`) lists them, so
  you get the documentation by declaring the flow.
- **A `FlowChip` in the palette** — the visible offer, from the first
  frame. This is the whole fix for "the best thing in the lab was the one
  thing a learner could not find".
- `flows()` / `startFlow(id)` on the root so an agent can start a lesson
  with one `eval`.

## Current kernel state — do not hallucinate beyond it

Implemented: `Flow`, `FlowStep`, `Narrator`, `FlowChip`, verbs-as-data
with `let` bindings, task/watch/expect, checkpoint scrubbing, ripening
pacing, `takeOver`, `LabLang` narration keys (the `flow.*` chrome lives
in the kernel dictionary — never copy it into a lab), and the headless
run `Lab.runFlow(flowId)` (every `Flow` registers itself with `Lab`
under its `flowId`; `Lab.headless` is what the Narrator, the professor
kit's `FlowGuide` and narration audio stand down for). **Not yet built**
(planned, don't reference in code): `FlowSet`, a flow picker,
`FlowCursor` (animated pointer), callout bubbles, flows as files under
`labs/<lab>/flows/`, resume-after-reload of a running flow, record mode.
Declare flows inline in `Sandbox.qml` and expose `flows()` / `startFlow(id)`
manually until then.
