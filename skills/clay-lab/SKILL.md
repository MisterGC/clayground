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

**Decide the purpose before writing either.** A lab is built for
**learning** (you are working it out), **teaching** (you are explaining
it to someone) or **research** (you are measuring something), and the
paper and board are structured differently for each — a study path, a
lesson plan or a lab report; a growing concept map, a reveal storyboard
or a model diagram. State it in the paper's opening. The skeletons are in
`references/triad.md`; picking the wrong one produces a document that
reads as padding, and a purpose that shifts means re-cutting the paper
rather than appending to it.

Flows currently live inline in `Sandbox.qml` (a `flows/` dir convention is
planned, not built). Papers and boards are authoring artifacts — the lab
never links against textli or grafli. See `references/triad.md` before
writing them; see `references/flows.md` before authoring a flow;
read `references/pitfalls.md` **before writing any 3D/QML lab code** —
every entry there cost a debugging session.

A lab is published as well as run locally: it launches full-screen from its
own page via `/labs/run/?lab=<slug>`, served out of `docs/labs-run/`. That
costs one convention — **every directory the lab imports needs a `qmldir`**,
including the lab's own, because a directory cannot be listed over HTTP. See
*Publishing to the web* in the pitfalls.

## Bootstrap a fresh session

Every fresh worktree rediscovers these the hard way. In order, before any
lab work:

1. **The base may be stale** — a worktree is often cut from an older
   branch than the one you were told to build on. `git log --oneline -1`,
   compare against that branch, and if it differs `git rebase <branch>`
   and check again. Everything below fails confusingly on a stale base.
2. `git submodule update --init --recursive` — Box2D, jsonata and the
   csv-parser live there; configure fails without them.
3. Configure with `cmake --preset default`. Explicit-flags fallback:
   `cmake -B build -DCMAKE_PREFIX_PATH=<Qt>/macos
   -DCMAKE_POLICY_VERSION_MINIMUM=3.5
   -DOPENSSL_ROOT_DIR=$(brew --prefix openssl) -DBUILD_TESTING=ON`.
4. **Build targets are QML module names, not directory names**: `ClayLab`
   (never `clay_lab`), `ClayCanvas3D`. Each module also has a *plugin*
   half (`ClayLabplugin`) that is what a running sandbox actually loads —
   building only `ClayLab` gives you `plugin "ClayLabplugin" not found`.
   Build everything once (`cmake --build build -j 8`); target-build after.
5. Verify with `clayrender` — the cheat-sheet at the end of this file.
   It needs a real GUI session (never `QT_QPA_PLATFORM=offscreen`), and
   never start or kill a dojo the person may be sitting in front of.

## Layout, running, boundaries

```
plugins/clay_lab/        the kernel (import Clayground.Lab)
labs/kits/<domain>/      domain kits: pure-JS model + QML visuals + strings.js
labs/<lab>/              one lab = one situation, dojo-runnable
labs/<lab>/records/      committed run records + the driver that makes them
labs/<lab>/studies/<slug>/   one question asked of the lab (see Studies)
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
6. **Theme + i18n from the first commit.** Only `LabTheme` tokens — for
   sizes and spacing as much as for colour: `font.pixelSize:
   LabTheme.fontBody`, `LabTheme.spaceL`, `LabTheme.px(280)`, never a bare
   number. And no bare user-visible literal, ever — `LabLang.t("key")`,
   `LabLang.num(v, digits)`, `LabLang.qty(v, unit)` from the start
   (retrofitting 80 sites is a whole session).
7. **Flow(s).** At least one, bilingual, with a real learner task —
   `references/flows.md`.
8. **Verify** with clay-crew: load check, determinism run, behavior
   assertions, real-input pass, screenshots only for visual claims.
9. **Paper + board last**, from committed run records rather than from
   measured numbers you are holding — *From measurement to paper* below,
   then `references/triad.md`.

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
  [{probe, label, color, style, sigmaProbe}]` when the plotted set is
  runtime-chosen; `series: []` draws the placeholder, `null` falls back to
  all probes. One autoscaled axis ⇒ plot **one quantity at a time** (I/V/P
  switch pattern), clear samples on switch. `style: "scatter"` for a
  quantity that arrives as discrete events — joining fixes with a line
  invents values nobody measured; `sigmaProbe` fills the ±σ band behind a
  curve, so "where it is" and "what that is worth" are one picture.
  Hovering the chart reads every series back at the nearest sample.
  `Probe.summary()` carries `mean` and `stddev` (Welford, stable over the
  full 1200-sample ring).
- **`BudgetBar`** — composition of a fixed total (where the EMF goes);
  use it when shares-of-a-whole is the lesson, not a trend.
- **`DataRecorder`** — probes → a **run record**, the citable artifact (see
  *From measurement to paper*). A `.csv` destination still writes the flat
  table for a spreadsheet, but a CSV carries no provenance and so cannot be
  cited. Always set an explicit destination (a relative default once
  littered the repo root), and set `command` to whatever regenerates the
  run — a record that cannot say how it was made is the thing this replaced.
- **`Scenario` / `ScenarioSet`** — named situations; imperative setup in
  `script` (initial QML property values don't fire change handlers). A
  *scenario* is a situation the lab ships and a learner can click; a **study**
  is a question asked of the lab and lives outside the ScenarioSet, built in
  `--eval` by a sweep. Do not grow the preset bar for every configuration a
  study wants to compare — four candidate networks belong in a manifest, not
  on four more buttons.
- **`Flow` / `FlowStep` / `Narrator` / `FlowChip`** — the guided, narrated
  walkthrough; the teaching spine. `FlowChip` is the visible offer to be
  taught — always ship one, or the flow is hidden behind a key nobody
  presses. (`Tour`/`TourStep` are legacy, superseded by Flow — never use
  them in new labs.)
- **`WorldLabel`** — 2D paper chip pinned to a 3D point (meter pills,
  value tags, selection cards). Sibling of the View3D, not inside it; it
  already carries the camera-dependency fix from the pitfall list.
- **`LabTheme`** / **`ThemeSwitch`** / **`ScaleSwitch`** — all
  colour/shape/type/spacing tokens in a light and a dark palette, plus
  `inkOn()` and `step()`; see Design language. Drop the switches beside
  `LangSwitch` top-right.
- **`LabLang` / `LangSwitch`** — runtime dictionary i18n (deliberately
  not `qsTr`: a dojo-hosted or WASM lab doesn't own the engine). Kernel
  chrome strings (`flow.*`, `keys.*`, `watch.*`, `rec.*`) are a built-in
  fallback layer — a lab never copies them, and anything it *does*
  register wins. `LabLang.qty(v, unit, digits)` is the quantity layer:
  SI prefixes with the mA↔A and ms↔s crossovers, in the language's
  notation. Never hand-roll one again.
- **`LabPrefs`** — theme, language and text size, persisted. Facts about
  the reader and the room, not about the run, so they survive a reload.
  Degrades to memory when `Clayground.Storage` is absent; a lab never has
  to think about it.

**Chrome — reach for these before writing a Rectangle.** They exist
because two labs hand-rolled each one; a third must not:

- **`LabPanel`** — the titled paper panel. Children stack in a column; for
  a fixed-size panel (canvas, chart) set `width`/`height` and bind the
  content to `panelId.body.width`/`.height`.
- **`LabKeys`** + **`LabHelp`** — the canonical map plus the lab's own keys
  as data (`{key, label, action}`). Call `keymap.handle(ev)` from the
  lab's `Keys.onPressed` and handle only what it returns false for; give it
  `pointer: nav` and call `handleRelease(ev)` from `Keys.onReleased` so the
  held-Space navigation can end. Declaring a key is documenting it —
  `LabHelp` (`?`) renders the same list, so the on-screen map can never
  drift from the code. The arrows and `WASD` are reserved for panning and
  are dispatched *after* the lab's own keys, so claiming one of those six
  letters silently takes a pan direction away — pick another letter.
- **`InstrumentBelt`** — what the viewer can pick up. **One line inside the
  `View3D`** (`pointer: nav`, `unit:` the lab's unit) plus `hands:` on
  `LabKeys`, and the lab has a `TapeMeasure` and a `Stopwatch`; a kit's own
  instrument is declared inside the belt and joins the same row. A ruler you
  have to install first is a ruler nobody reaches for. The tape's arithmetic
  is `measure.js`, checked by node — never re-derive a length in a paint
  call.
- **`ScenarioBar`** — clickable presets with `scenario.note.<name>`, the
  one-line reason each exists. Presets are the best teaching material a
  lab has; do not leave them keyboard-only.
- **`HintBar`** — bottom-centre; give it `flow:` so it yields to the
  Narrator, and `rightGuard: monitor` so a long translation clips instead
  of sliding under a panel.
- **`WatchMonitor`** — the watch→probe→curve loop. Supply only `valueOf`,
  `labelOf`, `quantities` (and `canWatch` for things with no reading);
  `watched` is the lab's watch set, and `prune()`/`clear()` keep it honest
  when objects are deleted. **`WatchChip`** is the per-object toggle
  (watch / watched / plot full — it reads the limit off the monitor, so a
  lab's own copy of it cannot disagree) and **`WatchMark`** the dot the
  object then wears in the world, in its curve's colour.
- **`Compass`**, **`GridMode`**, **`SelectionFrame3D`** — orientation,
  grafli's snap contract, and the shared hover/select language. The frame
  is what the circuit kit draws around a selected part; its lift is
  measured from the *object*, so a part sunk into its board needs a
  matching `height` or the bars end up inside the board.
- **`LabStage3D`** — the ground, the lights and the environment. See below;
  never build a 3D lab's ground by hand again.

**Instruments — the shelf.** Promoted from the labs, which proved each of
them (some three times over). Reach for one before drawing a dial:

- **`InstrumentScale`** + **`Gauge`** / **`BarFace`** / **`ColumnFace`** /
  **`DigitFace`** — the measurement and the faces that draw it. See
  *Choosing an instrument* below.
- **`InstrumentDock`** + **`DockedInstrument`** — HUD instruments the
  reader can put away. Also below.
- **`ReadoutPanel`** / **`ReadoutRow`** — swatch · name · live value, from
  data. `revision` re-reads it after an in-place mutation; `dim` fades a
  stale source and `bar` adds the share bar under a row.
- **`MiniMap`** — the abstract half of *dual representation*: fit-to-content
  projection plus the repaint plumbing, driven by a `draw(ctx, map)` the lab
  supplies. `map.px()` / `map.py()`, so the lab's paint code never does
  arithmetic on the panel's size.
- **`LabBanner`** — the centred status pill. Severity in the fill, ink from
  `inkOn()`, blink only for a live fault, width capped against a `guard`.
- **`TransportChip`** — sim time, pause and speed, driving
  `SimClock.timeScale` from outside. Until it existed no lab showed its
  clock, which is a strange gap in a framework that sells determinism.
- **`RecIndicator`** — the recording dot, so a growing CSV is never a secret.

### Choosing an instrument

**The split, in one line:** an `InstrumentScale` says what a reading
*means* — value or `probe`, unit, `min`/`max` or self-ranging `ranges`,
`logScale`, severity bands, `damping`/`settleTime`, `peakHold` — and a
*face* only draws it. Declare one scale, hand it to as many faces as the
page shows; they cannot disagree, because there is nothing to disagree
about. Adaptability lives in the model × face matrix: a music VU meter is
a `BarFace` on a log scale with peak-hold, **not** a new component.

Which face for which quantity:

- **`Gauge`** (needle) — *what is this relative to what the instrument can
  take*. The default for a self-ranging bench meter: give it `ranges` and
  it prints the one it settled on. Laid out in fractions of its own size,
  so it serves a HUD dial and a `Texture` baked onto a 3D part equally.
- **`BarFace`** — *how far along*: a level, a load, a share of capacity,
  an audio meter. Horizontal or vertical; `segments` turns the fill into
  the LED ladder a level meter has; peak-hold draws its marker here.
- **`ColumnFace`** — *how much*, read **off** the scale: a temperature, a
  wind speed, a tank. Thermometer-shaped, every major gradation labelled.
- **`DigitFace`** — *what is the number*. Mono digits through
  `LabLang.qty()`, so the SI prefix and the decimal separator match the
  readout beside it. Pair it with a needle or a column; alone it says
  nothing about what the number is worth.

Bands (`okUntil`/`warnUntil`, or an explicit `zones` list) are the
*scale's*, not the face's: declaring them once colours the needle, the
fill, the digits and the tint behind them, from `LabTheme`'s severity
tokens. A reading past the end of the scale takes the band at that end —
a pinned needle on a red-topped dial must not read back "ok".
`settleTime` is a swing for a value that changes on an *action*;
`damping` is the lag of a real movement, for a continuously noisy one.
Never both.

**The dock.** `InstrumentDock` is the HUD column: the lab declares each
instrument as a `DockedInstrument` (a `key`, a caption, a face inside),
the reader dismisses any of them with the ✕ in its corner, a tray at the
foot offers them back, and `dock.viewState()` merges into the lab's so the
set survives a reload. Which instruments are essential is a per-lab call —
the kernel only provides the mechanics.

`plugins/clay_lab/demo/Instruments.qml` is the reference page: one scale
under four faces, then the same faces skinned as an electrical bench
meter, an audio VU and a wind gauge.

### The stage

Every 3D lab stands on `LabStage3D`, and wiring it is the whole of a lab's
stage setup:

```qml
View3D {
    id: view3d
    LabStage3D {
        id: stage
        cellSize: root.cell
        gridMode: grid                                   // crosses vs dots
        workExtent: Qt.vector2d(root.boardW, root.boardH)
        shadowMapFar: 250                                // measured, per lab
    }
    environment: stage.environment
    OrbitCamera3D {
        id: rig
        homePivot: Qt.vector3d(0, 0, 0)
        panLeash: stage.workRadius                       // how far you may wander
        viewpoints: ({ "top": { pitch: 84, distance: 140 } })
    }
    camera: rig.camera
}
```

What it owns, so a lab does not: the `SceneEnvironment`, the three-light rig
with its measured shadow knobs, and one endless ground plane whose raster —
millimeter paper light, blueprint dark — is computed in the fragment shader
from world XZ, one line weight at any zoom, dissolving into the sky long
before the quad ends. No image, no board edge, and no peg `Model`s.

Three things to know:

- **`GridMode` draws nothing** — it holds the mode; the stage draws it, as
  crosses at the intersections while snapping and dots when free. Hand it
  over with `gridMode:`, and set `cueSize: 0` in a lab that places nothing
  (a snap cue on a surface nobody snaps to is a lie).
- **`worldAt(view3d, mx, my)`** is the pick: the plane is the only pickable
  thing the stage adds, so a mouse handler asks it rather than intersecting
  by hand. A raster that is not centred on the origin (an even column count
  puts the pegs on the half-cells) says so with `rasterOrigin`.
- **The overlay budget** is published, and nothing may z-fight the plane:
  flat markings sit between `stage.overlayMinY` (0.012) and
  `stage.overlayMaxY` (0.12) — `stage.overlayY(layer)` stacks them — with
  `depthBias` in `overlayMinBias..overlayMaxBias`. `depthBias` only settles
  sort order, so the lift is what actually does the work.

One trap the migration turned up, and it is not the stage's: a `WorldLabel`
takes its camera from the **view** (`camera: view3d.camera`), never from the
rig. Naming the rig's camera gets the label past its own null-guard while
the view still has none, and the first projection goes through a
*Cannot resolve view position* warning.

### Getting around

`OrbitCamera3D` turns and zooms; **`OrbitInput3D`** is what turns gestures
into those moves, so a lab never writes degrees-per-pixel again. It is
deliberately *not* a MouseArea: a lab that also picks, draws or drags keeps
its own MouseArea and asks it what a press means.

**Navigation is never a mode, and exactly one input changes meaning.** A lab
that builds something gives the left button to its tool, so the camera used
to end up on whatever was left over — and no two labs picked the same
leftovers (right-drag turned in street-network and panned in electronics).

There were modes twice. First one per activity (build / explore / measure),
whose shape fails the moment a third instrument is imagined: five modes for
one camera. Then two, build and use, which held up better and was still
wrong. What replaced them is below — moving, looking and using are live at
once, and the only thing you choose is what is in your hands.

- **the left button is never the camera's** — that is the whole rule, and
  every other one follows from it. A mode existed only because the camera
  wanted LMB: LMB-drag panned, so a lab that needed LMB had to be able to
  take it back, and the thing that took it back was the mode. An RTS has
  none of these problems because it never puts panning on the left button.
- **navigation, always** — RMB drags turn the view **about the point under
  the cursor**, the wheel zooms *towards the cursor*, the middle button
  pans, double-click focuses. Identical whether or not something is in the
  hand, and never taken away. A right *click* — under `clickSlop` pixels of
  travel — cancels instead, which is the RTS "put it down".
- **the click** — with an instrument in hand, an LMB *click* (under
  `clickSlop` pixels of travel) is reported through `picked`, carrying
  **both** the ground point and the object under the cursor, so a tape
  measure and a voltmeter need no gestures of their own. Anything further is
  a pan: repositioning is wanted far more often than another point, and a
  stray point is the more annoying mistake.
- **a lab with nothing to build** may spend LMB on the view deliberately —
  `panButtons: Qt.LeftButton | Qt.MiddleButton`, which is what
  sensor-fusion does. One decision, made once, by a lab that has nothing to
  select. It is not a mode: nothing flips it at runtime.
- **switching** — holding **Space** lends the view the left button while it
  is held (`springNav`, fed by `LabKeys`), `H` walks the belt, `P` keeps a
  reading. The belt shows what is held and the cursor changes
  (`cursorShape`). There is no build key and no mode chip, because there is
  no mode — a tool is something you pick up.

```qml
OrbitInput3D { id: nav; rig: rig; view: view3d }   // + panButtons: if nothing is built

MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: nav.cursorShape
    onPressed: (m) => {
        // nav declines first: "" means the press is the lab's, and with the
        // default buttons an LMB press is ALWAYS that case
        if (nav.begin(m.x, m.y, m.button, m.modifiers) !== "") return
        if (hands.held) { hands.press(m.x, m.y); return }   // the belt, before the tool
        myTool.press(m.x, m.y)
    }
    onPositionChanged: (m) => {
        if (nav.move(m.x, m.y)) return
        if (!pressed) nav.hoverAt(m.x, m.y)
        myTool.moveTo(m.x, m.y)
    }
    onReleased: {
        nav.end()                      // a flicked drag coasts to a stop from here
        if (hands.release()) return    // the click was the instrument's
        myTool.release()
    }
    onWheel: (w) => nav.wheel(w.angleDelta.y, w.x, w.y)   // x,y = zoom to cursor
    onDoubleClicked: (m) => nav.recenterAt(m.x, m.y)
}
// LabKeys { pointer: nav; hands: hands ... }
//   + Keys.onReleased: (ev) => keymap.handleRelease(ev)
// InstrumentBelt { id: hands; pointer: nav; unit: "m" }   // inside the View3D
```

A measurement itself is **never** in `viewState()`: it is a question being
asked now, not scene state. `Backspace` takes the last point back, `Esc`
clears the reading and then puts the instrument away, and putting it away
clears it too — holding Space does not, because the quasimode only borrows
the left button for as long as the key is down.

**Keeping one is the deliberate exception.** `P` pins the reading: the belt
asks for a name, and that name becomes a `Probe` sampled on the clock grid —
so the measurement is in the `.labrec` and a paper can cite it. It is asked
for rather than generated because a column called `dist_1` is a bad citation
forever. That is the whole arc: explore by hand → pin → recorded → cited.

**Writing a new instrument** is one file that says what it picks
(`pickKind: "point" | "object" | "moment"`), how many (`maxPicks`), and what
the reading means (`value`, `valueText`) — see `HandheldInstrument`. If you
find yourself writing gesture or camera code in one, the contract is being
worked around. The kernel ships the geometry instruments because every lab
has a ground plane and a clock; a kit ships the ones only it can mean.

Do **not** reintroduce a lab-local camera gesture (Shift-drag, "empty ground
orbits"): that is exactly the drift this rule exists to end, and a rule that
depends on what is under the cursor cannot be taught in one sentence. `nav.beginAs`
still exists for a lab whose own rule genuinely decides. Five things worth
knowing:

- **The pivot travels, on a leash.** `panBy` slides it along the ground;
  `panLeash` (from `homePivot`) keeps it near the work, softly — past the
  radius the pull-back grows, so there is a furthest point but no wall. The
  ground is endless; without this you get lost and there is nothing to
  navigate back by.
- **The goal pose is what serializes.** With `smoothMs` above zero the rig
  glides, so `yaw`/`pitch`/`distance`/`pivot` hold an interpolant mid-move
  while `goalYaw`…`goalPivot` hold the destination — and `state()` returns
  the goal. A `viewState()` taken mid-glide therefore restores where the
  camera was *going*. **Do not declare your own `Behavior` on a pose
  property** (duplicate binding); set `smoothMs` / `travelMs` instead, and
  move the rig with one call — a `pivot` write plus a `setDistance` starts
  two glides and the scene slides while it zooms. `applyState({px, py, pz,
  distance})` is the one-call form.
- **`viewpoints` + `goTo(name, ms)`** are named places, any subset of a pose
  (`{ pitch: 84 }` means "look down from wherever you are"), and yaw takes
  the short way round. `focusOn(points|point, pad)` is the verb a lab's own
  picking calls — a single point re-centres without diving at it.
- **Anchored moves keep their point on its pixel.** `reanchor(p)` slides the
  pivot onto the view axis at `p`'s depth — the pose comes out bit-for-bit
  unchanged, so it is invisible — and `orbitAround(p, dYaw, dPitch)` then
  rotates camera *and* pivot rigidly about `p`, which is what actually pins
  it. `zoomToward(p, factor)` dollies along the ray to `p` for the same
  reason. `OrbitInput3D` composes all three; a lab only calls them directly
  for a gesture of its own.
- **`FlowStep.view`** aims the camera on entering a step, once the `Flow` has
  a `camera:`: `{viewpoint: "top"}`, `{focus: [pts], pad}` or `{pose: {...}}`,
  applied *after* the demo so a step can frame what it just built. Steps
  without it behave exactly as before.

One trap, and it cost a render: `WatchChip`, `WatchMark` and `OrbitInput3D`
all declare a property whose name matches the id a lab habitually uses
(`monitor`, `rig`). Inside them `monitor: monitor` is a property assigned to
**itself** — it fails silently as an invisible chip. Expose the object under
a second name on the root (`readonly property alias watchMonitor: monitor`)
and wire `monitor: root.watchMonitor`.

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
- **Areas are `Poly3D`**, never a fan of line ribbons faked into a fill.
  Hand it a ring (`vertices`), inner rings as `holes`, and `extrude` for a
  prism — a lake, a plaza, a footprint, a building. Lift it slightly along
  its normal when it shares a plane with the ground; `depthBias` biases
  sort order, not depth, so it will not settle z-fighting. `showEdges` with
  `edgeMode: Triangles` is for labs where the *mesh* is the lesson; leave
  it off otherwise.
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

### One scale for the whole page

Type and spacing are tokens too, and all of them are multiplied by
`LabTheme.uiScale` (0.75–2.0, `ScaleSwitch` or `Ctrl+Plus`/`Minus`/`0`).
Seven type roles named by job — `fontMicro` (axis ticks) through `fontBody`
(chips, readouts) to `fontTitle` (narration, back of the room) — six
spacing steps `spaceXs`…`spaceXxl`, and `LabTheme.px(n)` for the one-off
geometry a named role would only obscure. The rules that make it a scale
(monotonic, growing at every rung, never collapsing a step to zero) are in
`tokens.js` and asserted by `node tokens.test.js`.

The reason it exists: a lab shown on a large external screen had HUD
controls nobody could read and nothing to turn, because every size in the
chrome was a bare pixel literal. So: **a bare `pixelSize:` in a lab is a
bug**, and a panel with a fixed width writes `LabTheme.px(280)`.

Turning it up is a stress test of the layout, and a page that only works at
100% has not been laid out. Anchor panels to each other rather than to the
window, and decide what gives way first — captions before instruments, the
second view of the same data before the first. `plugins/clay_lab/demo/`
reflows its plot row from *under* the instrument column to *beside* it when
the column no longer fits; copy that shape.

Theme, language and scale are persisted through `LabPrefs` — they belong to
the reader, so a lab that came back small after every reload was the
original bug report. That store is the dojo's; a `clayrender` run gets a
throwaway one unless it asks for `--prefs user`.

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
look for anything that got *brighter* when the room got darker. Do the same
sweep at two scales — four pictures, one command each — and
`plugins/clay_lab/demo/Sandbox.qml` is the reference the chrome itself is
checked against.

### Canonical key map

`1..9` scenarios · `C` clear · `E` eraser · `V` values · `M` abstract
view · `Q` watch/plot · `F` frame selection · `0`/`Home` reset view · `R`
rotate · `Del` delete · `#` grid mode · `T` flow ·
`H` takes the next instrument, `P` keeps its reading · `Space` held hands
the view over (and `Space`/`→` next, `←` back while a flow runs),
`Backspace` undoes a measured point *while something is in the hand*,
`Esc` cancel/leave · `Tab` focus mode · `Shift+R` record a run ·
`Ctrl+Plus`/`Ctrl+Minus`/`Ctrl+0` text size · **arrows and `WASD` travel
across the scene, `Shift`+arrows turn it, `+`/`-` zoom**. A lab may add
keys, never reassign these — and `W`, `A`, `S` and `D` are as reserved as
the arrows, which is why watching moved to `Q`. Key letters stay physical
across languages.
The arrows used to turn, which a drag already did well; crossing the scene
had no key at all, so turning moved onto `Shift`. While a flow runs `→`/`←`
are the flow's, so the arrows are the camera's only when nothing narrates —
and `Space` is the flow's too while it runs, which is why the quasimode
takes it only when nothing is narrating.
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

### Operating things in the scene

A part you can **operate** needs a hit region of its own, tested before the
regions that mean something else.

electronics-101's switch is the worked example and the cautionary tale. Its
body is 4.6 wide; its two wiring pads sit at ±3.5 with a 2.3 grab radius, so
the pads reached inward to ±1.2 and left a 2.4-wide strip in the middle as
the only place a click flipped the switch rather than starting a wire. On
screen that is a few pixels. The switch was clumsy to operate and mostly
answered by beginning a connection — which is precisely what it looked like
from the outside, and why it read as a bug in wiring rather than in the
switch.

The pattern:

- **An actuator region, first in the hit test.** `actuatorHalf(type)`
  returns half-extents for parts that have one and null for the rest, so the
  hit test stays a lookup rather than a special case for one type. Operating
  wins over wiring; the pads still wire because the actuator stops short of
  them.
- **Its own gesture.** An actuator press sets no selection, starts no drag
  and touches no pending wire, and fires on *release* — so a press that
  turns into a camera drag flips nothing.
- **Three signals that agree**, all reading one predicate (`hoverActuator`):
  a pointing-hand cursor, the part's own highlight (`actuatorHovered` on the
  component — the *lever* lightens, not the case), and a hint-bar line
  naming what the click will do. The hint outranks the wiring hint: pointing
  at a switch with a wire half-drawn is the exact moment the two get
  confused.

Do not signal it by recolouring something that already carries state — the
switch lever's colour is on/off, so hover *lightens* it rather than changing
it.

**Where state is set, and why the card usually wins.** A part's state belongs
on its selection card: a resistor's ohms are a slider there, a gate's
function a row of chips, a switch's on/off a pair of them. Four concerns,
four channels — navigate with the right button and `Space`, build with the
left button in the scene, inspect by selecting, and **operate on the card**.
The switch was for a while the only stateful part that broke that rule, and
the result was that building and operating felt like the same gesture,
because they were.

The card is also the only channel that survives having no pointer, which
matters: labs are published to the web, and there is no hover on a touch
screen.

Direct operation in the scene is then a *shortcut*, and it is gated on
selection — the part you picked is the part that responds. That is what stops
a click during building from flipping something, without introducing a mode
to remember: selection is the mode, and it is already visible. Say which of
the two clicks is next in the hint bar, or the two-step is something the
learner discovers by clicking twice and noticing.

### Focus mode

`Tab` clears the HUD: `LabView.focus` goes true and the instruments,
panels, plot, compass, clock and switches step out of the way. Only the
scene and — while a flow runs — the Narrator remain. It is for studying a
scene when nothing is being changed or measured.

Most of it is automatic. Anything built on `LabPanel` fades on its own, as
do the kernel's own pieces: `ParamPanel`, `Plot2D`, `WatchMonitor`,
`InstrumentBelt`, `InstrumentDock`, `DockedInstrument`, `HintBar`,
`Compass`, `TransportChip` and the three switches. **A lab only wires what
it built itself** — a scrim, a button declared beside a panel rather than
inside it — with `visible: !LabView.focus`.

Two rules worth knowing:

- `LabPanel` uses **opacity and `enabled`, not `visible`**. Labs bind
  `visible` on their own panels constantly (a section that is open, a card
  with something selected), and a component assigning it would be silently
  overwritten by exactly the labs that use it most. Nobody binds opacity on
  a panel.
- A panel that must survive focus mode sets `hideOnFocus: false`. The
  Narrator is not a `LabPanel` and stays by construction — a guided lesson
  without its narration is not a lesson.

The alarm banner deliberately does **not** hide. A short circuit outranks
whatever you were looking at.

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
   about color or position (never make a screenshot the only evidence).
   If the question is *numeric* — size, position, colour, count — query
   the resolved scene instead: `clayrender … --dump lines=out.json`
   returns the world-space points, widths, colours and style ids the
   renderer actually got, and `--project x,y,z` / `--pick x,y` answer
   "where does this land" and "what is under this pixel". A screenshot
   answers "does this read correctly to a human", nothing more.
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

## From measurement to paper

A lab's numbers are worth nothing until someone else can get them. The
path from a probe to a quoted figure is one artifact wide: the **run
record**.

A record is one committed text file per run — lab, scenario, seed, every
parameter, the per-probe series with mean/stddev/min/max, and the command
that regenerates it. JSON header, tab-separated table, no wall clock
anywhere, which is what makes two runs of one seed byte-identical.
`plugins/clay_lab/record.js` owns the format and explains its shape;
`DataRecorder` writes it; `labs/<lab>/records/` holds them, committed.

The loop, in order:

1. **Probe what the paper will claim.** If a sentence you intend to write
   names a number, that number needs a `Probe`. Reaching for the panel or
   your memory instead is how the last paper went stale. A probe records
   only finite values, so `NaN` is the honest answer for "no reading" —
   it leaves a blank cell rather than repeating the last one.
2. **Drive the run stepped, never live.** Frames are wall-clock, so a lab
   left to play itself is not reproducible. Stop the ticker and advance
   the clock:

   ```bash
   clayrender labs/<lab>/Sandbox.qml --out /tmp/x.png --frames 1 --eval "
       clock._frameTicker.running = false;
       clock.seed = 42;
       applyScenario('open-sky');
       recorder.lab = '<lab>'; recorder.destination = 'labs/<lab>/records/open-sky-42.labrec';
       recorder.recordId = 'open-sky-42'; recorder.command = '<how to redo this>';
       recorder.steps = 3600; recorder.stepSize = 1 / 60;
       recorder.recording = true;
       for (var i = 0; i < 3600; ++i) clock._advance(1 / 60);
       recorder.recording = false"
   ```

3. **Commit the driver beside the records.** One script per lab
   (`labs/<lab>/records/make.sh` — sensor-fusion has the reference one)
   that builds each record's `command` field out of its own path, so the
   record cannot claim a command that does not exist. Give it
   `--verify`: run each scenario twice and `cmp` the files. That command
   *is* the determinism evidence, and anyone can re-run it.
4. **Read the table off the records, not off the run you remember.**
   Then quote by id, with the regeneration command once per section. The
   staleness contract in `references/triad.md` is the full rule.

When the numbers are meant to answer a *specific question* rather than to
document the lab, the loop above is wrapped by a **study** — same records,
plus the question and its validity argument, and a runner that expands the
matrix for you. See *Studies* below.

Two traps this loop has already caught, both worth expecting:

- **State that survives a scenario reset leaks into the record.** A
  lab-level `lastUpdate`-style cache that `onWasReset` does not clear
  puts a reading from the cold-open scenario into the record of a
  different one. Reset everything the probes can see.
- **Scenarios are not comparable at one seed.** A sensor that produces no
  fix draws no random numbers, so disabling one shifts the shared stream
  for everything downstream. Two scenarios at one seed are two noise
  realisations. Say so, or sweep seeds.

## Figures — what a paper is allowed to show

A lab is a thing you look at, and a paper about one that shows nothing is
poorer than it needs to be. Figures are cheap here — `clayrender` puts the
scene in any state and photographs it — so the only real questions are
where they live, whether they can be made again, and what they are allowed
to claim.

```
labs/<lab>/figures/            beside paper.md
    make.sh                    regenerates EVERY figure below it
    <name>.png                 committed, and never edited by hand
```

A study keeps its own `figures/` next to its `study.md`, same shape.

**Five rules, and the last one is the one that matters.**

1. **Every figure is regenerated by `make.sh`, or it is not a figure.** A
   picture nobody can remake is a screenshot: it rots the first time the
   lab changes and there is no way to tell that it has. One script, one
   invocation, all of them — so "does the paper still look like the lab?"
   is a re-run and a `git diff`, exactly like `--check` is for a record.
2. **Photograph a chosen instant, not a lucky one.** Same determinism a
   record gets: `clock._frameTicker.running = false`, then step the clock
   to the moment worth showing. A frame is a wall-clock interval, so a lab
   left to play itself gives a different picture every run and every diff
   is noise. Add `--settle` so the capture waits for the frame to stop
   changing.
3. **Crop by name.** `--crop <objectName> --crop-pad 8` cuts out the
   palette, the card, the plot — wherever it currently is. A hand-measured
   rectangle silently becomes a picture of the wrong corner the moment the
   UI scale or the window size changes. Give anything a figure might want
   an `objectName`; the kernel's one-per-lab widgets already have one
   (`belt`, `hint`).

   **Crop, never shrink the window.** A lab's HUD is responsive: rendering
   into a small viewport to keep a panel out of frame reflows the layout
   into something no user has ever seen and elides panel text into "the
   current…". Capture at the size the lab is really used at and take the
   region you want — or hide the panels you do not.

4. **Ship the full resolution.** Never downscale a figure to make it fit:
   textli scales an over-wide picture down to the prose column by itself,
   and Enter on one fills the window from the **file**, not from the
   scaled page copy. A pre-shrunk screenshot has thrown away the only
   detail that view exists to show and bought nothing. Tune the *framing*
   — what is in the frame, how close the camera is, which panels are
   hidden — and leave the pixel count alone.
5. **A figure is illustrative. No number in the prose may be read off
   one.** Numbers come from probes and records — that is the whole point of
   the record — and a figure is how a reader *recognises* what the numbers
   are about. Say so in the paper where the figures appear, the way the
   study does: *"the figures are illustrative only; every number comes from
   `records/`."* A caption may name a value that a record backs; it may
   never be the source of one.

**What earns one.** The setup at the moment its lesson is visible; a
close-up of a reading, so an instrument is recognisable when the text
names it; a *pair* on one seed where the paper's argument is a contrast
(this is the strongest kind — same everything, one thing changed); a piece
of UI the prose makes a claim about, because a claim about what something
teaches at a glance cannot be checked in words. Decoration earns nothing.

Renders never inherit your settings — `clayrender` persists to a throwaway
store — so every figure comes out at the default theme, language and UI
scale whatever your dojo currently looks like. That is what keeps a set of
them consistent, and why a figure of a German lab needs `--eval
'LabLang.lang = "de"'` rather than your session.

```bash
clayrender labs/electronics-101/Sandbox.qml \
    --eval 'clock._frameTicker.running = false' \
    --eval 'applyScenario("parallel"); showValues = true' \
    --eval 'clock.reset(); for (var i = 0; i < 60; ++i) clock._advance(1/60)' \
    --settle --size 1400x900 \
    --out labs/electronics-101/figures/parallel.png
```

Reference: `labs/electronics-101/figures/make.sh` (a paper's set) and
`labs/street-network-101/studies/topology-four-houses/figures/make.sh` (a
study's pair).

## Answerability — what a lab may be asked

Before any run that is meant to answer a question, map **every quantity
the question needs** onto one of three things:

| the question needs… | it maps to | how you check |
|---|---|---|
| something to turn | a `Parameter` | `Lab.labInfo().params` — it exists or it does not |
| something to read | a `Probe` | `Lab.labInfo().probes` — likewise |
| something the model must hold | a **model-card** claim | `labs/kits/<kit>/README.md`, section *Model card* |

The first two halves are mechanical: `labInfo()` proves a knob or a
reading exists, and an agent can check it without opinions. The third is
not, and is the one that matters — only the model card can say whether
the physics holds for *this* question. That is why every kit has one, and
why it states its simplifications with a direction of effect rather than
as a disclaimer.

Whatever stays unmapped forces one of exactly two outcomes, stated in the
write-up before the method:

- a **reduced question** the lab genuinely can hold ("how much does
  landmark *geometry* cost a fix" instead of "how accurate is lidar
  localisation"), or
- **"not answerable with this lab"**, with the missing quantity named.

Neither is a failure; producing confident numbers about a question the
model cannot hold is. A solar lab with no location and no season cannot
answer "how much energy will the sun provide" — it can answer "how does
output vary with panel angle, for a fixed lamp". The second is a real
result. The first would be a fabrication with a plot behind it.

Each kit's card ends with **Questions it can answer** and **Questions it
cannot** for exactly this step; read that list before the parameters.
When a question fails the gate for a *mechanical* reason — a knob that
does not exist — the honest options are to add the knob (and say the lab
changed) or to reduce the question; never to approximate the knob with
something adjacent and not mention it.

## Studies — a question asked of a lab

A lab is a *capability space*: what can be done here. A **study** is one
specific question posed against it, with its validity argument, its method,
its data and its write-up in one reviewable place.

```
labs/<lab>/studies/<slug>/
    study.md      the question, the answerability mapping, the method,
                  the manifest, and — after the sweep — results + conclusion
    records/      one committed .labrec per run
    results.md    generated FROM those records by lab-sweep; never hand-edited
    figures/      optional, with a make.sh that regenerates them
                  (see *Figures* above for the rules they follow)
```

Reference: `labs/street-network-101/studies/topology-four-houses/`.

**`study.md`, in this order**, and the order is the point — the validity
argument is made *before* any number exists, so it cannot be written to fit
the answer:

1. **The question**, in one sentence, plus what "better" means and why that
   is the right objective.
2. **Answerability** — the table from the section above, every quantity the
   question needs mapped to a parameter, a probe or a model-card claim, and
   an explicit list of what had to be **reduced** or added. If nothing was
   reduced, say so; a mapping with no losses is suspicious often enough to
   be worth stating.
3. **Method** — what a run is, why the warm-up is that long, and the
   manifest.
4. **Results**, quoted by record id.
5. **Conclusion**, with its limits attached.

A **student assignment is the same file with the answer cut off.** Put a
`<!-- results:begin -->` marker before Results, and the student edition is
everything above it, without `records/` and `results.md`. That is why the
question, the honesty argument and the method come first: they are the
assignment, and the results are what the student is meant to produce.

### The manifest

One fenced `json` block inside `study.md`, declaring
`"manifest": "clay-lab-study/1"`. It lives inside the prose so that reviewing
the study *is* reviewing what was run; JSON rather than YAML because the
runner is stdlib-only and a hand-rolled YAML subset would be a parser with
its own bugs between a claim and its evidence. Multi-line JS is written as an
**array of lines**, which diffs one statement at a time.

```json
{
  "manifest": "clay-lab-study/1",
  "study": "topology-four-houses",
  "lab": "labs/street-network-101/Sandbox.qml",
  "objective": { "probe": "arrivals", "statistic": "stddev",
                 "normalize": "mean", "direction": "minimize" },
  "report":  [ { "probe": "waiting", "statistic": "mean" } ],
  "record":  { "probes": ["arrivals", "waiting"] },
  "run":     { "warmupSteps": 1800, "steps": 3600, "stepHz": 60, "budget": 16 },
  "fixed":   { "demand": 0.5 },
  "setup":   ["clearPlan()", "setHouses([[-70,-45],[70,-45]])"],
  "parameters": [
    { "name": "topology", "kind": "eval", "levels": [
        { "id": "ring", "eval": ["addRoad(-70,-45, 70,-45)"] } ] }
  ],
  "seeds": [11, 23, 42, 57]
}
```

`kind` is `eval` (build it through the lab's action API), `scenario` (a name
the lab ships) or `param` (a `Parameter` value). `run.budget` is a **hard
cap** on matrix size — widening a sweep has to be a deliberate edit, not
something that happens.

### Running it

```bash
tools/lab-sweep/lab-sweep <study-dir> --check     # answerability, no runs
tools/lab-sweep/lab-sweep <study-dir> --dry-run   # print the matrix
tools/lab-sweep/lab-sweep <study-dir>             # run it, write results.md
tools/lab-sweep/lab-sweep <study-dir> --only topology=ring --seed 42
```

`--check` loads the lab, reads `labInfo()`, and proves every probe and
parameter the study names exists — the mechanical half of the gate, and it
says on success that it is only the half. Run it before every sweep; a
misspelled probe otherwise costs a full matrix.

`lab-sweep` is deliberately dumb: no search, no early stopping, no fitting.
It steps the clock by hand (so records are byte-stable), isolates every run's
prefs, and reads the results table back out of the records rather than out of
whatever the runs returned. Deciding *what* to sweep next stays with you.
Details: `tools/lab-sweep/README.md`.

### Three traps this study already hit

- **A spread is not comparable across cells of different scale.** Ranking
  four networks by raw `stddev(arrivals)` ranked them by their means, because
  the means differed fourfold. `"normalize": "mean"` (a coefficient of
  variation) asks the question that was intended. Check your objective
  against the levels' *magnitudes* before you trust a ranking.
- **Record the warm-up and every cell looks alike.** From cold, a rate climbs
  from zero; that ramp is identical in every configuration and swamps the
  difference you are measuring. Warm up unrecorded, then record.
- **Pin the fleet, not the density.** If demand scales with the size of the
  thing being varied, a comparison of shapes secretly measures size. Whatever
  the domain, find the quantity that has to be held constant for the
  comparison to mean anything, and check it in the results (the study quotes
  `mean(cars)` per network for exactly this).

## Agent operation cheat-sheet

**Which tool.** Anything you can express as *"put the lab in state X and
show me"* goes to `clayrender` — one command, no session, and several
variants render in parallel:

```bash
clayrender labs/electronics-101/Sandbox.qml --out shot.png --size 1400x900 \
    --settle --scale 0.6
```

The sandbox is positional or `--sbx <file>`, whichever the surrounding
script already speaks — the dojo's spelling works here too, and giving both
is an error rather than a guess. It renders through the GPU into a window
that is never shown, so it needs a real graphics session: under
`QT_QPA_PLATFORM=offscreen` or bare ssh, View3D content comes out blank.
Exit codes are the report: **0** rendered clean, **1** never loaded (or a
`--set`/`--eval` failed), **2** rendered but the scene logged warnings or
errors — treat it as a failed render, not a picture with a footnote — and
**3** a `--wait-for` that never came true, with no image written.

`--set` **assigns**, it does not call — use `--eval` for anything that runs
code, and `--script file.js` for a setup too long for one line. They apply in
command-line order, so this is one command, not a dojo session:

```bash
clayrender labs/electronics-101/Sandbox.qml --out shot.png \
    --set 'showLabels=false' --eval 'applyScenario("parallel")' \
    --wait-for 'ready' --settle
```

`--wait-for` holds the capture until the expression is truthy; if it never is,
clayrender exits 3 and writes **no** image, so a picture of a state you never
reached cannot end up in your evidence.

**Renders cannot dirty the person's settings.** Whatever a render persists
through `LabPrefs` — theme, language, UI scale — goes to a throwaway store
that dies with the process, so `--eval 'LabTheme.mode="dark"'` stays inside
that one render and the next one is light at 100% again. No reset ritual at
the end of a render series. Two escapes when you need them: `--prefs user`
writes the real store the dojo reads (so a flip there *does* stick — end
that series at `LabTheme.mode="light"` and `LabTheme.resetScale()`), and
`--prefs <dir>` keeps one throwaway store across a series. The carrier is
`CLAY_STORAGE_DIR`, honoured by any host that sets it before building its
engine.

Use the dojo for interaction, hot-reload iteration and anything stateful
(driving a flow, real input, a determinism run across steps). Query the
scene rather than screenshotting whenever the question is numeric.

Through clay-crew's `eval`: read state `Lab.labInfo()`; set a parameter
`Lab.set('gpsSigma', 5)`; jump situations `applyScenario('tunnel')`
(or `reload` + `rearm`); start a lesson `startFlow('led-basics')`;
assert with `Lab.probeSummary()` and `trace` on probe expressions.
No inspector protocol extensions exist for labs — conventions only.
