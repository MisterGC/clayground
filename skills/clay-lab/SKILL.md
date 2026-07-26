---
name: clay-lab
description: >
  Compose Clayground labs — deterministic, agent-verifiable teaching and
  experiment spaces — from the clay_lab kernel and the domain kits, and
  author the full lab triad (Sandbox.qml + paper.md + overview.grafli +
  strings.js + flows). Use this skill when creating or extending anything
  under labs/ (labs or kits), when working with Clayground.Lab components
  (Lab, Parameter, Probe, SimClock, Plot2D, Flow, Narrator, LabTheme,
  LabLang), or when the user asks for a new lab, kit, teaching space, or
  simulation playground. Companion of clay-crew, which owns verification
  through the inspector — load clay-crew whenever you verify.
---

# Clay Lab — composing labs for Clayground

A lab is a small interactive world a person can stand inside and push on:
parameters to turn, probes plotted live, scenarios to jump between, and a
flow that narrates and demonstrates. Labs are composed from tested blocks,
not written from scratch — your output is composition, short and
reviewable, and every claim a lab makes is verified before handover.

Three identities at once, all mandatory:

- **Deterministic** — same seed + same stepped frames ⇒ identical probe
  series. This is what makes labs verifiable, teachable (a flow can replay
  a moment) and research-grade (sweeps reproduce).
- **Agent-operable** — everything a user can do is reachable through
  `eval` via the conventions below; you prove behavior with the
  inspector (clay-crew skill), you never "ship and hope".
- **Teaching-first** — a lab that explains nothing is a toy. Ship at
  least one flow, and put the lesson in the app, not only in the paper.

## Definition of done — the triad

A lab is finished when `labs/<lab>/` contains, consistent with each other:

| File | Role |
|---|---|
| `Sandbox.qml` | the lab itself, dojo-runnable |
| `strings.js` | every user-visible string, EN + DE, from the first commit |
| `paper.md` | depth: the model, its math, stated simplifications, **measured** results (textli conventions) |
| `overview.grafli` | overview: concept topology, deep links into the paper (grafli conventions) |

Flows currently live inline in `Sandbox.qml` (a `flows/` dir convention is
planned, not built). Papers and boards are authoring artifacts — the lab
never links against textli or grafli. See `references/triad.md` before
writing them; see `references/flows.md` before authoring a flow;
read `references/pitfalls.md` **before writing any 3D/QML lab code** —
every entry there cost a debugging session.

## Layout, running, boundaries

```
plugins/clay_lab/        the kernel (import Clayground.Lab)
labs/kits/<domain>/      domain kits: pure-JS model + QML visuals + strings.js
labs/<lab>/              one lab = one situation, dojo-runnable
```

- Labs are **not CMake targets**. Run them live:
  `./build/bin/claydojo --sbx labs/<lab>/Sandbox.qml`
  or headless for verification:
  `QT_QPA_PLATFORM=offscreen ./build/bin/clayliveloader --sbx labs/<lab>/Sandbox.qml`
- The loader watches **only the sandbox dir**: after editing kit files,
  request an inspector `reload`; after editing `plugins/clay_lab/` (or any
  plugin QML), **restart** the loader — plugin QML is baked in via rcc,
  a reload is not enough.
- **Kit vs lab**: the kit owns the domain (solver, part visuals, symbols,
  vocabulary in its own `strings.js`); the lab owns the situation (UI,
  scenarios, narration, key handling). The test: could a second lab use
  this kit without editing it? A kit graduates to `plugins/clay_<domain>/`
  once ≥2 labs use it unchanged.
- **Kit model code is pure JS** (`.pragma library`, no Qt types, no clock,
  no randomness of its own) so it runs under node in a second:
  every kit ships a unit suite like `labs/kits/traffic/traffic.test.js`
  (pragma-stripped eval, covers derivations and sim invariants).

Reference labs, in reading order for a new author:

| Lab | Teaches you |
|---|---|
| `labs/physics-playground/` | minimal kernel-only lab, Box2D clock |
| `labs/sensor-fusion-101/` | continuous 3D lab: sensors, Kalman, watch steps, produced GNSS error |
| `labs/electronics-101/` | build-type lab: palette, wiring, per-part controls, dual representation, richest conventions |
| `labs/street-network-101/` | draw → derive → simulate: planar road graph, derived lane model, kit unit suite |

## The composition recipe

Work in this order; each step has a verification before the next.

1. **World + clock.** `SimClock { seed; sampleInterval }` is the only
   source of time and randomness. With a Box2D world attach it
   (`world:`); world-less labs get per-frame stepping automatically —
   never advance sim state in lumps, step it frame by frame.
2. **Domain model** in the kit as pure JS; write its node unit suite now,
   not later.
3. **Kernel wiring.** Parameters for owner-less globals, probes for every
   quantity worth a curve, `Plot2D` bottom-right. Wire the monitor
   `series` from a watch list, not a fixed set, if the user chooses what
   to plot.
4. **Scenarios.** Named, scripted situations; a lab always cold-opens
   into one. Applying a scenario resets clock + RNG — that is the
   reproducibility anchor.
5. **Conventions block** (skeleton below) — this is what makes the lab
   operable by the inspector, by flows, and by you.
6. **Theme + i18n from the first commit.** Only `LabTheme` tokens; no
   bare user-visible literal, ever — `LabLang.t("key")` and
   `LabLang.num(v, digits)` from the start (retrofitting 80 sites is a
   whole session).
7. **Flow(s).** At least one, bilingual, with a real learner task —
   `references/flows.md`.
8. **Verify** with clay-crew: load check, determinism run, behavior
   assertions, real-input pass, screenshots only for visual claims.
9. **Paper + board last**, from measured numbers — `references/triad.md`.

## Block catalog — when to reach for what

Kernel (`import Clayground.Lab`):

- **`Lab`** (singleton) — registry. `Lab.p(name)` / `Lab.set(name, v)` /
  `Lab.labInfo()` / `Lab.probeSummary()`; `Lab.sampled(t)` is the signal
  consumers listen to (bindings on `Probe.samples` never fire — the
  array mutates in place).
- **`SimClock`** — seeded clock; `random()/randomRange()/randomGaussian()`
  are the *only* legal randomness. `wasReset` lets sensors/estimators
  snap at scenario boundaries. `timeScale` is the sim-speed knob (bind a
  `simSpeed` parameter to it; `timeScale: 0` is your pause verb).
- **`Parameter`** — a *global*, real-valued tunable, only for things with
  no owner (noise sigma, sim speed, demand). Anything owned by an object
  gets a **per-object control** on its selection card instead — removing
  a global in favor of per-object made electronics simpler *and* more
  capable.
- **`Probe` + `Plot2D`** — time series. `Plot2D.series:
  [{probe, label, color}]` when the plotted set is runtime-chosen;
  `series: []` draws the placeholder, `null` falls back to all probes.
  One autoscaled axis ⇒ plot **one quantity at a time** (I/V/P switch
  pattern), clear samples on switch.
- **`BudgetBar`** — composition of a fixed total (where the EMF goes);
  use it when shares-of-a-whole is the lesson, not a trend.
- **`DataRecorder`** — probes → CSV. Always set an explicit destination
  inside the lab's dir (a relative default once littered the repo root).
- **`Scenario` / `ScenarioSet`** — named situations; imperative setup in
  `script` (initial QML property values don't fire change handlers).
- **`Flow` / `FlowStep` / `Narrator` / `FlowChip`** — the guided, narrated
  walkthrough; the teaching spine. `FlowChip` is the visible offer to be
  taught — always ship one, or the flow is hidden behind a key nobody
  presses. (`Tour`/`TourStep` are legacy, superseded by Flow — never use
  them in new labs.)
- **`WorldLabel`** — 2D paper chip pinned to a 3D point (meter pills,
  value tags, selection cards). Sibling of the View3D, not inside it; it
  already carries the camera-dependency fix from the pitfall list.
- **`LabTheme`** / **`ThemeSwitch`** — all colors/shape/type tokens in a
  light and a dark palette, plus `inkOn()` and `step()`; see Design
  language. Drop `ThemeSwitch` beside `LangSwitch` top-right.
- **`LabLang` / `LangSwitch`** — runtime dictionary i18n (deliberately
  not `qsTr`: a dojo-hosted or WASM lab doesn't own the engine). Kernel
  chrome strings (`flow.*`, `keys.*`) are a built-in fallback layer — a
  lab never copies them, and anything it *does* register wins.

**Chrome — reach for these before writing a Rectangle.** They exist
because two labs hand-rolled each one; a third must not:

- **`LabPanel`** — the titled paper panel. Children stack in a column; for
  a fixed-size panel (canvas, chart) set `width`/`height` and bind the
  content to `panelId.body.width`/`.height`.
- **`LabKeys`** + **`LabHelp`** — the canonical map plus the lab's own keys
  as data (`{key, label, action}`). Call `keymap.handle(ev)` from the
  lab's `Keys.onPressed` and handle only what it returns false for.
  Declaring a key is documenting it — `LabHelp` (`?`) renders the same
  list, so the on-screen map can never drift from the code.
- **`ScenarioBar`** — clickable presets with `scenario.note.<name>`, the
  one-line reason each exists. Presets are the best teaching material a
  lab has; do not leave them keyboard-only.
- **`HintBar`** — bottom-centre; give it `flow:` so it yields to the
  Narrator, and `rightGuard: monitor` so a long translation clips instead
  of sliding under a panel.
- **`WatchMonitor`** — the watch→probe→curve loop. Supply only `valueOf`,
  `labelOf`, `quantities` (and `canWatch` for things with no reading);
  `watched` is the lab's watch set, and `prune()`/`clear()` keep it honest
  when objects are deleted.
- **`Compass`**, **`GridMode`**, **`SelectionFrame3D`** — orientation,
  grafli's snap contract, and the shared hover/select language.

Framework blocks labs lean on: `ClayWorld3d` + `OrbitCamera3D`
(`Clayground.Canvas3D` — yaw/pitch/distance on a leash, `F` frames,
`0` resets, min-height anti-clip), `Box3D` with toon shading,
`LineBatch3D`/`MultiLine3D` (flat lines + chevron flow animation),
`Label3D` (leader lines; `showLeader` defaults false), `VoxelMap`,
`clay_behavior` (MoveTo/FollowPath), `clay_algorithm` (`KalmanFilter2D`,
`GridPathfinder`), `SceneLoader3d`/`clay_svg` for floor plans,
`Clayground.Storage` for persistence.

## The conventions contract

The root item implements these; together they are what lets the
inspector, flows and agents drive the lab like a user would:

```qml
import QtQuick
import Clayground.Lab
import "../kits/<domain>/strings.js" as KitStrings
import "strings.js" as Strings

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: {
        LabLang.register(KitStrings.dict)  // kit vocabulary first...
        LabLang.register(Strings.dict)     // ...lab copy may override
        forceActiveFocus()
        applyScenario("intro")             // always cold-open into a scenario
    }

    // a time-driven lab advances in FIXED steps, or the run depends on the
    // machine it ran on; the clock owns the accumulator
    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.1
        fixedStep: 1 / 60
        onStepped: (dt) => root.stepSim(dt)
    }
    Parameter { name: "simSpeed"; value: 1; from: 0.1; to: 5 }
    Probe { name: "output"; expr: () => system.output }
    GridMode { id: grid }

    ScenarioSet {
        id: scenarioSet
        Scenario { name: "intro"; script: () => { /* imperative setup */ } }
    }

    // --- inspector / agent / flow conventions -------------------------
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }
    function labInfo() { return Lab.labInfo() }   // language-neutral: ids
    function flagInfo() { return labInfo() }      // and types, never t()'d
    function viewState() {                        // the user's whole place
        return { cam: camRig.pose(), lab: Lab.viewState() /* + your state */ }
    }
    function applyViewState(s) {
        if (s.cam) camRig.apply(s.cam)
        Lab.applyViewState(s.lab)                 // re-steps world-less clocks
    }
    function flowActions() {                      // verbs as data, see flows.md
        return { "setParam": (n, v) => Lab.set(n, v) }
    }
    function flows() { return [introFlow.flowId] }
    function startFlow(id) { if (id === introFlow.flowId) introFlow.start() }
    function frameAll() { rig.frame(everything(), 1.25) }   // LabKeys uses these
    function frameSelection() { rig.frame(selected(), 1.25) }

    // --- chrome -------------------------------------------------------
    LabKeys {
        id: keymap
        lab: root; camera: rig; flow: introFlow; recorder: recorder
        keys: [{ key: "V", label: "key.values",
                 action: () => root.showValues = !root.showValues }]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: 300 }
    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) cancelWhateverIsInProgress()
    }
}
```

Ordering contract, easy to get wrong: on restore the loader applies the
rearmed **scenario first** (it resets clock + RNG), then
`applyViewState` — and **the user's own serialized state wins over the
preset** (electronics restores the exact board and only falls back to the
scenario when there is none). `Lab.applyViewState` re-steps world-less
clocks bit-identically; a Box2D world cannot be re-stepped synchronously,
so those labs restore scenario + parameters and resume from the boundary.

Put the user's *whole* place into `viewState()` — camera, selection,
toggles, and for build labs the entire built artifact (electronics
serializes the circuit; street-network the road graph) — that is what
makes the fix loop and flow checkpoints seamless.

## Design language — paper and ink

One theme for all labs: `LabTheme` (grafli's design DNA — paper
`#e8e4dd`, panel `#f5f2ed`, ink `#2f3437`, muted meaning-bearing accents,
radius 8, border 2, `monoFont` for structure, `handFont` for hints), in a
**light and a dark palette** that `ThemeSwitch` swaps at runtime.
Rules that make labs read as one product:

- **Flat and glare-free.** Toon shading (`useToonShading`), no specular
  (`specularAmount: 0`), no IBL. Shapes read by silhouette and value,
  never by highlight. Real shadow maps, tuned by *measurement* (pixel
  sweep), never by eye — knob values in the pitfall list.
- **Lines lie flat** on the surface (`Flat` + `depthBias`) — ribbons
  can't cast shadows, and flat buys chevron flow animation. Direction is
  a chevron pattern; speed is bucketed **relative to the scene's own
  maximum**, so a junction visibly splits.
- **Print identity onto parts** (render-to-texture dials, labels,
  ON/OFF plates) instead of 3D glyphs. Teach the real convention
  wherever a decoration would do: actual resistor color code, IEC
  symbols — the difference between a toy and a kit.
- **Color carries information across surfaces**: a watched part wears
  its curve's color on the object *and* in the legend. Three or four
  semantic colors, no more; pick from the named tokens.
- **Dual representation, one model.** The 3D scene shows what you built;
  an abstract panel (schematic, lane graph, scan display) shows what it
  *is*, derived from the same data. Highest-value pattern we know; `M`
  toggles it.
- **One toggle that states the lesson** (`V` labels every part: series
  vs parallel becomes readable rather than explainable).
- **Hover/select language**: thin quiet outline on hover; selection is
  thick + a nose mark showing facing + a 2D card with the per-object
  controls.

### Light and dark — the four rules

Both palettes live in `plugins/clay_lab/palette.js`, and
`palette.test.js` asserts the *relationships* rather than the colours, so
a palette edit is checked against the rule that made the original value
correct. Read the header of `palette.js` before touching a colour; the
same doctrine runs in grafli and textli, and the dark ground `#1e1c19` is
shared with both to the byte.

- **Never pin an ink over a fill.** Use `LabTheme.inkOn(fill)` for every
  chip, badge, pill and banner. `color: active ? "#ffffff" : ink` is the
  single most repeated bug in this codebase — it looks right only while
  the fill happens to be dark, and a palette that lifts that fill breaks
  it silently. Eight lab sites and four kernel widgets had it.
- **Say how far, not which way.** `LabTheme.step(c, amount)` replaces
  `Qt.darker()` on anything that must survive both themes: a grid line
  drawn by removing light has nothing to remove on a dark ground, so it
  is drawn by adding light instead. An amount below 1 moves the other way.
- **The board has its own roles.** `board` (the sky / `clearColor`),
  `table`, `sheet`, `inkSolid` (a rim or wall — ink as a *lit surface*,
  which cannot simply invert or it becomes a light source), plus
  `ambient3d` and `shadowFactor`. The 2D `paper`/`paperDeep` are not
  substitutes: a recessed 2D well still sinks in the dark while the
  board's ordering inverts.
- **Colour that means something keeps its identity.** The paper says
  "the rose track is GPS" and the legend has to agree in both themes, so
  data tokens are measured on the dark ground and kept unless they fail
  to read there — nine of twelve survive untouched. Never re-derive a
  token because the theme changed; lift it only if it fails, and along
  its own hue.

Verify a new lab in both: toggle via the inspector
(`{"action":"eval","eval":["LabTheme.toggle()"]}`), screenshot each, and
look for anything that got *brighter* when the room got darker.

### Canonical key map

`1..9` scenarios · `C` clear · `E` eraser · `V` values · `M` abstract
view · `W` watch/plot · `F` frame selection · `0` reset view · `R`
rotate · `Del` delete · `#` grid mode · `T` flow · `Space`/`→` next,
`←` back, `Esc` cancel/leave · `Shift+R` record CSV. A lab may add
keys, never reassign these. Key letters stay physical across languages.
Surface every key you handle: palette buttons carry their shortcut,
the hint bar teaches the rest, and the header comment lists them all.

### HUD slots

palette top-left · compass under it · abstract view bottom-left ·
monitor (plot + quantity chips) bottom-right · banner top-centre · hint
bar bottom-centre · language and theme switches top-right ·
parameters right. The
Narrator owns bottom-centre while a flow runs — hide the hint bar then
(`flow.running`). Hard rule: **text panels are width-capped and elide**
— a translation is routinely 25% longer than the English it replaced
(cap against neighboring panels, not `root.width`).

### Localization

- No bare user-visible literal, from the first commit; numbers through
  `LabLang.num(v, digits)`, never `toFixed` in UI code.
- Kit registers its vocabulary, lab registers its copy, lab may
  override the kit. Register both **before** the first `applyScenario`.
- `labInfo()` stays language-neutral (ids and types, not display
  labels); flow narration keys are `flow.<flowId>.<stepKey>` in both
  languages.

## Determinism contract and verification

Every lab must: (a) derive all randomness from `SimClock` — and
**visualization must never consume the sim RNG stream** (decorative
jitter uses a hash, not `clock.random()`); (b) run correctly under the
inspector's `time` pause/step actions; (c) expose `labInfo()`.

Verify in this order (clay-crew skill has the full protocol):

1. `qmllint` + `waitForRoot` after every edit round.
2. **Determinism run**: apply a scenario, `time`-step N frames, record
   probe series; repeat with the same seed; byte-identical or it's a bug.
3. **Assertions over screenshots**: `eval` the quantity you changed;
   screenshot only for a visual claim, pixel-sample it when the claim is
   about color or position (offscreen View3D grabs can come out blank —
   never make a screenshot the only evidence).
4. **Drive the real input path** (synthetic clicks/keys) at least once
   per feature — property pokes hide real bugs (a pick-scan via
   `mapFrom3DScene` gets you screen coords for click targets).
5. **Kit JS**: run the node unit suite.
6. **Flows as tests**: run each flow headless with `pacing: "auto"`;
   every `demo` verb must resolve, every `task.until` must hold after
   its `solve`, every `expect` must pass. A drifted lab breaks its own
   lessons — that is the point.
7. **Measure, don't guess**, anything with a numeric knob (shadows,
   fades): parameter sweep + pixel sampling.

The authoring gym (`tools/loader/tests/gym/run_gym.py`) guards loader
conventions; labs add their determinism/flow checks there as they land.

## Agent operation cheat-sheet

Through clay-crew's `eval`: read state `Lab.labInfo()`; set a parameter
`Lab.set('gpsSigma', 5)`; jump situations `applyScenario('tunnel')`
(or `reload` + `rearm`); start a lesson `startFlow('led-basics')`;
assert with `Lab.probeSummary()` and `trace` on probe expressions.
No inspector protocol extensions exist for labs — conventions only.
