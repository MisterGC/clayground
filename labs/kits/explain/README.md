# Explain kit — mechanisms for showing a detail the scene hides

> **Prototype.** This kit is the #269 evaluation bench, merged so the follow-ups have it in the tree. #272–#276 promote its pieces into the kernel and #279 deletes it afterwards — build on those, not on this.

Issue #269 asks how a lab lesson gets *inside* a thing: the professor points
at the transistor and says "three legs, a base current, a chip inside", and
the learner sees a black lump. This kit holds one prototype per way of
answering that, all explaining the same subject — the NPN transistor of
`labs/kits/circuit` — so they can be compared side by side in
`labs/kits/explain/Sandbox.qml` (scenarios `1`–`4`, `5` the favourite
combination of 1 and 3 as one lesson, `T` runs the lesson of the current
one).

| approach | type(s) | what the learner sees |
|---|---|---|
| 1 exploded view | `ExplodedView3D`, `ExplodePart`, `TransistorAnatomy3D` | the part comes apart in place; the professor points at each piece |
| 2 callouts | `CalloutLayer` | rings on the sub-parts with leader lines to captioned cards, revealed one by one; the case can be ghosted (`xray`) so the cards reach inside |
| 3 chalkboard | `Chalkboard`, `chalk.js` | a documentary cut to a slate; the drawing draws itself in real time — a cross-section, arrows, a graph — while the narration goes on |
| 4 dive-in | `DiveIn`, `TransistorInterior3D`, `carriers.js` | the professor shrinks, the camera flies through the case, and the die is a landscape with carriers moving in it — driven by the lab's own numbers |

`anatomy.js` is the one description of the subject (parts, teaching order,
exploded offsets, die geometry) that 1, 2 and 4 build from; `chalk.js`
draws the same layers. Nothing in the kit is electronics-specific except
`TransistorAnatomy3D`, `TransistorInterior3D` and the two drawings in
`chalk.js` — those are the *content*; everything else is a mechanism a lab
about anything can use.

## Rules every type in this kit follows

These are the contract the four prototypes were built against and what a
kernel promotion has to keep.

1. **Goal and interpolant are two properties.** Everything that animates
   has a plain, assignable *goal* (`spread`, `revealed`, `shown`,
   `progress`, `inside`) and a read-only `…Now` interpolant that eases
   toward it (`spreadNow`, `progressNow`, `depth`). A flow step sets the
   goal and an `expect` asserts the goal; `Lab.runFlow()` steps sim time
   without an event loop, so an interpolant can never be asserted headless.
2. **Language-neutral.** A type takes display text as data (`label`,
   `detail`, `caption`, a `labels` dictionary) and never calls `LabLang.t`
   itself; ids are authoring tokens (`die.base`), identical in every
   language. The sandbox owns `strings.js`.
3. **Verification seams over screenshots.** Every type answers a numeric
   question about itself: `partAt(id)` (a scene point), `screenOf(i)`,
   `count`, `depth`, `report()`. A claim about the picture is checked
   through these first.
4. **Theme tokens only** — `LabTheme` for every colour, size and font.
   The two admitted literals are physical part colours (the epoxy `#2a2724`
   the circuit kit already uses, and the slate of a chalkboard), each
   commented as such.
5. **Pure-JS models with a node suite** (`anatomy.js`, `chalk.js`,
   `carriers.js`): `.pragma library`, no Qt types, no clock, no randomness
   of its own; deterministic in `time`. `node labs/kits/explain/<x>.test.js`.
6. **Nothing here touches the kernel.** A change that seems to need one is
   written down in the evaluation instead (see `EVALUATION.md`).
7. **Colour by role.** `anatomy.js` roles map to: `epoxy` → `#2a2724`,
   `metal` → `LabTheme.muted`, `gold` → `LabTheme.highlight`,
   `n` → `LabTheme.secondary`, `p` → `LabTheme.accent`,
   `print` → `LabTheme.sheet`. Shading is the circuit kit's: matte,
   `specularAmount: 0`, toon boxes.

## The types

### `ExplodedView3D` (approach 1) — a generic exploded assembly

```qml
ExplodedView3D {
    id: assembly
    spread: 0                    // goal, 0 assembled .. 1 exploded
    unit: 1.0                    // scales every part's offset
    focus: ""                    // part id; every other part dims to dimOpacity
    dimOpacity: 0.25
    glideMs: 900                 // how long spreadNow takes to reach spread
    ExplodePart { partId: "lid"; offset: Qt.vector3d(0, 4, 0); order: 1 /* Models */ }
}
```

- `readonly property real spreadNow` — the interpolant. `readonly property bool animating`.
- `readonly property var partIds` — every `ExplodePart` child's id, in child order.
- `function partAt(id) -> vector3d` — the part's **scene** position now
  (assembled pose + `offset * spreadNow * unit` + the part's `anchor`), for
  a finger or a mark. Unknown id → `Qt.vector3d(NaN, NaN, NaN)`.
- `function idsInOrder() -> [string]` — parts with `order > 0`, ascending.
- `ExplodePart` is a `Node`: `partId`, `offset` (full-spread displacement,
  local), `anchor` (local point a mark/finger lands on, default the part's
  own origin), `order` (0 = never explained on its own), `role` (a string
  from `anatomy.js`'s roles, informational), `readonly dimmed`.
- Default property is the part list (`ExplodePart` children only).

### `TransistorAnatomy3D` — the subject, as an `ExplodedView3D`

The NPN as `labs/kits/circuit/CircuitElement3D.qml` draws it at
`spread 0` — same silhouette, same pads (`anatomy.js: PADS`), same
silkscreen — with the inside modelled: the header on the collector lead,
the three-layer die from `anatomy.js: dieStack()`, two bond wires to the
base and emitter legs. Every part id in `anatomy.js: PARTS` is an
`ExplodePart` with that table's `offset`, `order` and `role`.

Adds: `xray: 0..1` (goal; `xrayNow`) — the epoxy parts' opacity goes to
`1 - xray`, so callouts can reach the die without exploding. Standing on
the board at `position`, the part occupies the same cell footprint as the
circuit kit's transistor (±4.6 × ±4.6).

### `CalloutLayer` (approach 2) — captioned marks with leaders

Screen space over the `View3D`, same parent as it, like `MarkLayer`.

```qml
CalloutLayer {
    anchors.fill: parent
    view: view3d; camera: rig.camera
    callouts: [{ at: vector3d, label: "Base", detail: "the thin P layer that…",
                 side: "auto" | "left" | "right", index: 2 }]
    revealed: -1                 // goal: how many (in list order) are up; -1 = all
    numbered: true               // a badge with `index` (or the list position) on the ring
    keepOut: null                // { x, y, width, height } screen rect, as MarkLayer
    cardWidth: LabTheme.px(220)
}
```

- A callout = ring on the point + leader (ring → elbow → card edge) + card
  (badge, `label` bold, `detail` under it, elided to two lines).
- Cards on one side stack top-down without overlapping; `side: "auto"`
  puts the card on the side of the screen the point is farther from.
- Reveal is sequential: each newly revealed callout fades/slides in over
  `revealMs` (220). `readonly property int shownCount` follows.
- `function screenOf(i) -> vector3d` (`z <= 0` behind the camera),
  `function cardRectOf(i) -> {x, y, width, height}`.
- Projection lists `camera.scenePosition` / `camera.sceneRotation` as
  dependencies (the `MarkLayer` freeze trap).

### `Chalkboard` (approach 3) — the documentary cut

An overlay over the whole lab: a scrim over the 3D scene, a slate with a
chalk drawing that draws itself, a caption line under it.

```qml
Chalkboard {
    anchors.fill: parent
    drawing: Chalk.transistorSection(labels)   // from chalk.js
    progress: 0                  // goal 0..1, how much is drawn; progressNow eases
    drawMs: 6000                 // wall time for progress 0 → 1 when set in one step
    shown: false                 // goal; open/close run the transition
    caption: ""                  // the narration line under the board
    inset: 0.08                  // board margin, fraction of the shorter side
}
```

- `function open(ms)` / `close(ms)` set `shown` and glide;
  `readonly property real presence` 0..1 is the transition interpolant;
  `readonly property bool transitioning`.
- The transition: scrim (`LabTheme.ink` at ≤ 0.6) fades in, the slate
  scales 0.94 → 1 and fades in, 450 ms, `OutCubic`. Closing reverses it.
  The 3D scene stays visible, dimmed, around the slate.
- Chalk look: strokes drawn on a `Canvas`, round caps, a second faint
  jittered pass for grain; jitter from a hash of the op index, never
  `Math.random`. Chalk colour `LabTheme.paper`; the slate is a physical
  colour (dark green-grey), the frame `LabTheme.muted`.
- Text ops appear letter by letter in `LabTheme.handFont`.
- `function report() -> { shown, progress, progressNow, ops, opsDrawn }`.

`chalk.js` — the drawing model, Qt-free:

- A drawing is `{ width, height, ops: [...] }` in its own unit space
  (the renderer fits it into the slate). Ops: `line {from, to}`,
  `rect {at, size}`, `arrow {from, to}`, `text {at, text, size}`,
  `curve {points}`, `axes {at, size, xLabel, yLabel}`, `plot {at, size,
  points}` (points already in axes units 0..1), `pause {ms}`.
- `length(op)` — how much "ink" an op costs (px for strokes, a per-glyph
  cost for text, `ms * speed` for a pause); `total(drawing)`.
- `at(drawing, progress) -> [{ op, frac }]` — every op up to the cursor,
  the current one with `frac` in (0, 1), nothing after it. This is what
  the `Canvas` draws.
- `transistorSection(labels)` — the N-P-N cross-section with the base and
  collector current arrows, labelled from `labels` (`n`, `p`, `collector`,
  `base`, `emitter`, `ib`, `ic`).
- `gainGraph(beta, labels)` — axes, the `Ic = β · Ib` line and the
  saturation knee, labelled from `labels`.
- Suite: `chalk.test.js` (lengths add up, `at()` is monotone and clamps,
  a drawing's ops are well-formed).

### `DiveIn` (approach 4) — shrink and fly inside

```qml
DiveIn {
    id: dive
    rig: rig; presenter: prof; view: view3d
    target: anatomy              // has partAt(); the interior stands at target.partAt("die.base")
    interior: interior           // the TransistorInterior3D
    ghosts: [anatomy]            // what fades to ghostOpacity while inside
    inside: false                // goal; depth eases 0 → 1 over diveMs
    diveMs: 2200
    presenterScale: 0.06         // presenter height3d inside, as a factor of its outside height3d
    clipNearInside: 0.04
}
```

- `function enter()` / `leave()` set `inside`. `readonly property real
  depth` is the interpolant. `readonly property bool travelling`.
- What `depth` drives, all from one number: the rig glides to a fit of the
  interior (`rig.fit`, pitch ~18) with `minDistance`/`minHeight`/`clipNear`
  relaxed for as long as `inside` (restored on leave, like
  `CameraDirector`'s portrait floors); the presenter's `height3d` glides to
  `presenterScale ×` its outside value and it `travelTo`s the interior's
  `standPoint`; `ghosts` fade to `ghostOpacity` (0.12); `interior.reveal`
  follows `depth`.
- `function report() -> { inside, depth, rigDistance, presenterHeight }`.

`TransistorInterior3D` — a `Node` at the die's position, at part scale
(die footprint from `anatomy.js: DIE`, so ~1.6 units): the three layers as
slabs with the two junction planes marked, and **carriers** — small
spheres travelling emitter → base → collector along `carriers.js` paths,
their number and speed bound to `baseCurrent` and `collectorCurrent`
(normalised 0..1). Exposes `time` (bind to the lab clock), `reveal` (0..1
fade), `standPoint` (where a shrunken presenter stands), `partAt(id)` for
`emitter | base | collector | junction.eb | junction.bc`. Everything
moving is a pure function of `time` (`carriers.js: carriersAt(t, iB, iC,
n)`), never of a timer.

## How a lab drives them

Every mechanism is a **verb** in the sandbox's `flowActions()`
(`explode`, `xray`, `focus`, `callouts`, `chalk`, `dive`) so a `FlowStep.demo`
switches it as data and `Lab.runFlow()` can replay it; the professor's
`FlowGuide` resolves `subjectOf`/`mark` names through `anatomy.partAt(id)`,
so pointing and marks land on the piece the line is about. Directed
steps get the same verbs as custom script cues
(`guide.script.registerVerb("explode", …)`), e.g. `*explode* Three legs…`.

## Checking it

```bash
node labs/kits/explain/anatomy.test.js
node labs/kits/explain/chalk.test.js
node labs/kits/explain/carriers.test.js
./build/bin/clayrender labs/kits/explain/Sandbox.qml --out x.png --paused \
    --result - --eval 'Lab.runFlow("explain-exploded")'      # one per approach
./build/bin/claydojo --sbx labs/kits/explain/Sandbox.qml            # look at it
```

Each type has its own bench under `bench/` (`ExplodeBench.qml`,
`CalloutBench.qml`, `ChalkBench.qml`, `DiveBench.qml`) — a stage, a rig,
the component and a `report()` — for working on one mechanism without the
others.

## As built — where the prototypes departed from the contract above

The contract was written before the four types existed; the types kept its
names and semantics and departed in these named places, each for a reason
measured on the way. The findings and the verdict are in `EVALUATION.md`.

- `ExplodedView3D` has no `default property list<ExplodePart>`: a
  `list<T>` does not parent into the 3D scene graph, so the parts would not
  draw. It uses `Node`'s own default property and collects duck-typed parts
  (`partId`/`offset`/`basePosition`) on completion; `parts` exposes the
  list. `ExplodePart` gained `basePosition` (the authored pose), `ghost` (a
  second opacity factor, so an x-ray and the focus dimming do not fight
  over one property) and `anchorScene`.
- `TransistorAnatomy3D.xray` maps to `1 - xray` as written, which makes 1
  a deletion; the sandbox drives 0.75. Node `opacity` blends on
  `PrincipledMaterial` and on `Box3D` in Qt 6.11.1 — no material tricks.
- `CalloutLayer` draws the badge on the ring *and* on the card, answers
  `cardRectOf()` as `{0,0,0,0}` for a card that is not on screen, and adds
  `autoRule` (`"far"` as specified, `"near"` — what the sandbox uses,
  because the far rule crossed leaders over a centred subject), `live`
  (per-frame re-projection: `mapFrom3DScene` answers zeros until the view
  has drawn once, and a still camera never re-triggers a binding),
  `visibleCount`, `layout`.
- `Chalkboard.chalkColor` defaults to `LabTheme.inkOn(slateColor)`, not
  `paper` (near-black in the dark palette); the scrim is `paperDeep` in the
  dark theme and `ink` in the light one (`ink` inverts); `scrimOpacity`,
  `transitionMs` and `safe` (px guards, so the slate keeps out of the
  narrator's strip) were added. `chalk.js` gained `cut()`, `subOps()`,
  `validate()` and the geometry helpers the renderer and the pricing share.
- `TransistorInterior3D`'s slabs are `#Cube` + blended `PrincipledMaterial`
  with `BoxLine3D` outlines, not `Box3D` (its material does no alpha
  blending); the junctions are rings, not plates (a plate at 18° hid the
  collector's carriers). `carriers.js` assigns lanes in two blocks so a
  change of base current does not reshuffle every carrier.
- `DiveIn` fits all eight corners of `bounds()` plus the presenter with
  `presenterHeadroom` (a two-corner fit hung six corners off the frame),
  returns through a registered viewpoint and `goTo(name, ms)` because
  `applyState` has no duration, and writes `interior.reveal` itself — a
  lab must not bind it too.
- Benches: `LabKeys` dispatches letters only, so a digit key a bench wants
  is handled in its own `Keys.onPressed` and does not appear in `LabHelp`.
