# Clayground.Lab

The experiment kernel for Clayground Labs: turns any sandbox into an
interactive, deterministic, agent-verifiable experimentation space.

## Components

- **Lab** (singleton) — registry connecting everything; agents read/write
  parameters via `Lab.p(name)` / `Lab.set(name, value)` and fetch
  `Lab.labInfo()` through the inspector's eval action.
- **Parameter** — named, ranged tunable; bind your system to `value`.
- **Probe** — named observable sampled on a fixed sim-time grid.
- **SimClock** — seeded deterministic clock; with a `world` attached, sim
  time advances with the physics steps (exact under the inspector's
  `time`/`step` action); seeded `random()`/`randomRange()` are the only
  randomness a lab may use.
- **ParamPanel** — auto-generated slider panel for all parameters. Rows are
  `Tab`-reachable and arrow-operable, with a visible focus ring.
- **Plot2D** — live autoscaled strip chart of probes. Pass `probes` for a
  fixed set, or `series: [{probe, label, color, style, sigmaProbe}]` when the
  plotted set is built at runtime: the lab then owns naming and colouring, an
  empty array draws `placeholder` instead of every probe, and legend entries
  become clickable (`seriesClicked`) so the user can drop a curve where it is
  named. `style: "scatter"` leaves discrete measurements unjoined,
  `sigmaProbe` fills a translucent ±σ band behind a curve, and hovering the
  chart reads every visible series back at the nearest sample.
- **DataRecorder** — probe samples to CSV (via `Clayground.Text`).
- **LabTheme / ThemeSwitch / ScaleSwitch** — every colour, shape, type and
  spacing token, in a light and a dark palette that swap at runtime, all
  multiplied by one `uiScale` factor. The two palettes are counterparts
  rather than inversions, and the rules that make them so live (and are
  tested) in `palette.js` — most importantly `LabTheme.inkOn(fill)`, which
  every chip and badge must use instead of naming an ink, and
  `LabTheme.step(c, amount)`, which moves a colour away from the ground in
  whichever direction the palette has room. The measurement half is
  `tokens.js`: seven type roles (`fontMicro` … `fontTitle`), six spacing
  steps (`spaceXs` … `spaceXxl`) and `LabTheme.px(n)` for one-off geometry.
  `node palette.test.js` and `node tokens.test.js` check the relationships,
  not the values.
- **LabPrefs** — the three settings that belong to the person rather than to
  the run: `ui.theme`, `ui.scale`, `ui.lang`. Backed by `Clayground.Storage`
  when it is present and by memory when it is not, so a lab that never links
  the storage plugin still runs — it just forgets on exit.
- **LabLang / LangSwitch** — runtime language switch for a published lab.
  Whoever owns a vocabulary registers it (`LabLang.register(dict)` with
  `{lang: {key: text}}`), strings are ordinary bindings on `LabLang.t(key)`
  / `tf(key, ...)`, and `LabLang.num(v, digits)` prints numbers in the
  language's notation (German gets a decimal comma; `Plot2D`, `BudgetBar`
  and `ParamPanel` already use it). `LabLang.qty(v, unit, digits)` adds the
  quantity layer on top — SI prefixes with the mA↔A, ms↔s and k/M crossovers
  every lab used to hand-roll (`format.js`, `node format.test.js`). Not
  `qsTr`: retranslating a live engine is a C++ call on the `QQmlEngine`,
  which a lab hosted by the dojo or exported to WASM does not own. Drop
  `LangSwitch` in a corner and it offers exactly the registered languages.
- **Scenario / ScenarioSet** — named, scripted situations wiring the
  `scenarios()`/`applyScenario()` inspector convention; applying resets
  the clock so runs are reproducible.
- **Flow / FlowStep / Narrator / FlowChip** — the guided, narrated
  walkthrough: verbs-as-data driven through the lab's own `flowActions()`,
  demo/task/watch steps, hint→solve escalation, checkpoint scrubbing.
  `FlowChip` is the on-screen offer to be taught, so the lesson is not
  hidden behind a key nobody knows.

### Chrome — what makes two labs look like one product

Everything below was hand-rolled in two labs before it moved here.

- **LabPanel** — the titled paper panel every HUD is made of; children
  stack, or set a size and anchor to its `body`.
- **LabKeys / LabHelp** — the canonical key map (`1..9` presets, `T` flow,
  `f` jump labels / `⇧F` frame (plain `F` in a jump-less lab), `0` reset,
  `H` takes the next instrument, `P` keeps its reading,
  `Shift+R` record, `?` help, arrows and `WASD` travel, `Shift`+arrows
  turn) plus the lab's own keys as data.
- **HintJump** — keyboard selection: `f` labels every target the lab
  names (1–2 home-row letters), typing one selects it in place; off-screen
  targets become a grouped badge strip and *do* fly on pick. The lab
  supplies `targets()` (id, world pos, name, group) and wires
  `jump:` on LabKeys; the letters are physical, the capture follows the
  pin-prompt guard, and a focus loss puts the labels away. Declaring a key is what documents
  it: `LabHelp` renders the map from the same list, so the two can never
  drift. The six travel letters are reserved and dispatched *after* the
  lab's own keys, so claiming one silently costs a pan direction.
- **HintBar** — bottom-centre line that steps aside while a flow narrates
  and stays width-capped against its neighbours.
- **ScenarioBar** — clickable preset chips, each with the one-line reason
  it exists (`scenario.note.<name>`).
- **WatchMonitor** — watch a thing, get a probe, a colour and a curve;
  owns probe lifecycle, stable names and the one-quantity-per-axis rule —
  which, since traces became `(id, quantity)` pairs (`traceIn`), means one
  **strip** per traced quantity, stacked on a shared time axis and cursor
  (`maxStrips`, default 3). A part keeps one colour across strips, so its
  WatchMark matches every curve it owns.
  **WatchChip** is the per-object toggle that feeds it (watch / watched /
  plot full, the limit read off the monitor), **WatchMark** the dot the
  object then wears in the world, in its curve's colour.
- **WorldLabel** — 2D paper chip pinned to a 3D point.
- **SelectionFrame3D** — the shared hover/select language on the work
  surface (thin outline hovering, full frame plus facing mark selected).
  Used by the circuit kit; note that its lift is measured from the object,
  so a part sunk into its board needs a matching `height`.
- **Compass** — which way the work surface faces while you circle it.
- **GridMode** — snap/free placement with grafli's contract (`#` cycles,
  `Alt` inverts for one gesture). It holds the mode and draws nothing;
  **LabStage3D** is what shows it.
- **LabStage3D** — the ground every 3D lab stands on, plus the light rig
  and the `SceneEnvironment` that go with it. One quad, no texture: the
  raster is computed in the fragment shader from world coordinates, so it
  is millimeter paper on the light palette and blueprint on the dark one,
  one line weight at any zoom, and it dissolves into the sky rather than
  ending at a board edge. It shows `GridMode`'s mode as crosses or dots at
  the intersections, answers `worldAt(view, mx, my)` for mouse editing, and
  publishes the height/`depthBias` budget flat overlays have to stay
  inside. Three labs built a table, a sheet, a rim, a light rig and 585 peg
  `Model`s between them before this existed.

### Instruments — the shelf

Promoted from the labs, which had proved each of them (some three times over):

- **InstrumentScale** — what a reading *means*, with nothing that draws it:
  value or probe, unit, fixed limits or a self-ranging set of `ranges`,
  linear or log positioning, severity bands, nice-number gradations, and the
  lag and peak-hold of a real movement. One of these feeds as many faces as
  the page shows, so they cannot disagree.
- **Gauge** — the needle face. Given `ranges` it selects its own, and prints
  the one it settled on. Laid out in fractions of its own size, so the same
  component serves a HUD dial and a `Texture` baked onto a 3D part.
- **BarFace** — the level face, horizontal or vertical, optionally as the LED
  ladder of a level meter, with the held peak marked. A music VU meter is
  this on a log scale, not a component of its own.
- **ColumnFace** — the thermometer face: every major gradation labelled, for
  a quantity read *off* the scale rather than as a proportion.
- **DigitFace** — the numeric face, in mono digits through `LabLang.qty()`.
- **InstrumentDock / DockedInstrument** — the HUD column, where each
  instrument can be put away by the reader and taken back out of a tray at
  its foot. The visible set rides in the lab's `viewState()`.
- **ReadoutPanel / ReadoutRow** — swatch · name · live value rows, built from
  data, with an optional share bar per row.
- **MiniMap** — the abstract view: fit-to-content projection plus the repaint
  plumbing, driven by a `draw(ctx, map)` callback the lab supplies.
- **LabBanner** — the centred status pill, severity in the fill and the ink
  from `inkOn()`, blinking only for a live fault.
- **TransportChip** — sim time, pause and speed, driving `SimClock.timeScale`
  from outside.
- **RecIndicator** — the recording dot, so a growing CSV is never a secret.

### Instruments you hold

The shelf above is *mounted*: the lab author bound what each one measures
when the lab was written, and it reads for the whole run. These are the
other half — the viewer binds the subject at runtime by pointing, and the
reading dies with the gesture.

- **HandheldInstrument** — the contract. An instrument declares what a click
  contributes (`pickKind`: a `"point"` on the ground, an `"object"` in the
  scene, or a `"moment"` in sim time), how many it takes (`maxPicks`, 0 for
  an endless chain), and what the reading means (`value` / `valueText`). It
  handles no input and knows nothing about the camera. That is the
  acceptance test: a new instrument is one file saying what it picks and
  what that means, with no gesture code in it.
- **InstrumentBelt** — what the viewer can pick up, and the owner of the
  hand's click. One line inside the `View3D` (`pointer: nav`, `unit:` the
  lab's unit) and the lab has a **TapeMeasure** and a **Stopwatch**; a kit's
  own instrument is declared inside the belt and joins the same row. A ruler
  you have to install first is a ruler nobody reaches for.
- **TapeMeasure** — the screen-space tape. Its arithmetic is `measure.js`,
  checked by node, so lengths and angles are not geometry that only exists
  inside a paint call.
- **Stopwatch** — the same contract against the sim clock rather than the
  ground.
- **CameraAnchorMark** — the dotted ring showing what the view is orbiting
  and zooming about. A screen-space overlay, because as world content it
  clipped into geometry at close range.

`pin()` is the one transition out: it names the reading, registers it as a
`Probe`, and from then on it is sampled on the clock grid like any other —
so it lands in the run record and a paper can cite it. It asks for the name
because that name is what gets cited. A measurement itself is never in
`viewState()`: it is a question being asked now, not scene state.

### The mouse

One rule, and the rest follows from it: **the left button is never the
camera's**. A mode used to exist only because the camera wanted LMB — panning
sat there, so a lab that needed LMB had to be able to take it back, and the
thing that took it back was the mode. `OrbitInput3D` declines the left button
instead, so nothing has to.

- **RMB** drag turns the view about the point under the cursor; a right
  *click* cancels — the "put it down" gesture.
- **Middle drag** pans, **wheel** zooms towards the cursor, **double-click**
  focuses. Always live, never taken away.
- **LMB** is the lab's: its own tool, or a click handed to whatever
  instrument is in the hand. Holding **Space** lends it to the camera for as
  long as the key is down.
- A lab with nothing to build may spend LMB on the view deliberately
  (`panButtons: Qt.LeftButton | Qt.MiddleButton`) — one decision, made once,
  not a mode.

## The determinism contract

Every lab must (a) derive all randomness from `SimClock` (seeded),
(b) run correctly under the inspector's `time` pause/step actions,
(c) expose `labInfo()` — typically just `return Lab.labInfo()`.
Same seed + same stepped frames ⇒ identical probe series.

## Minimal lab skeleton

```qml
import QtQuick
import Clayground.Lab

Item {
    SimClock { id: clock; seed: 42 }
    Parameter { id: pGain; name: "gain"; value: 1; from: 0; to: 5 }
    Probe { name: "output"; expr: () => mySystem.output }

    ParamPanel { anchors.right: parent.right }
    Plot2D { anchors.bottom: parent.bottom; width: parent.width; height: 150 }

    ScenarioSet { id: scen; Scenario { name: "default"; script: () => {} } }
    function scenarios() { return scen.names() }
    function applyScenario(n) { scen.apply(n) }
    function labInfo() { return Lab.labInfo() }
    function flagInfo() { return Lab.labInfo() }
}
```

See `demo/Sandbox.qml` — a damped oscillator with a noisy measurement, used
as an excuse to put every instrument on one page, and the fastest way to see
whether a change to the palette or the scale has broken anything. Render it at
two scales in two themes:

```bash
clayrender plugins/clay_lab/demo/Sandbox.qml --out shot.png --size 1400x900 \
    --eval 'LabTheme.mode = "dark"' --eval 'LabTheme.uiScale = 1.6' --frames 300
```

`labs/electronics-101/` is a full lab.
