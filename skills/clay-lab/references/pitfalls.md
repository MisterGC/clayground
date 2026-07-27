# Lab-authoring pitfalls

Every entry here cost at least one real debugging session. Read before
writing lab code; skim again when something "impossible" happens.

## 3D placement and texturing

- **`Box3D`'s origin is bottom-centre** (Y=0 is the floor of the box),
  not the centre. A part positioned as if centred floats half its height
  above the surface — and it looks *almost* right, which is why it ships.
- **`#Cube` maps the same texture onto every face.** Sink a printed
  plate into the body so its sides don't smear, or use a `#Rectangle`
  plane instead. A cube's up face needs `flipU` **and** `flipV`; a plane
  needs **neither**.
- **Render-to-texture works inline**: `Texture { sourceItem: Item {...} }`
  inside a `Repeater3D` delegate is fine — that is how meters get real
  dials and batteries printed labels.
- **A material's `parent` is the `Model`, not the enclosing `Node`** —
  use explicit ids when wiring materials.
- **`View3D` does not auto-assign a camera.** Without an explicit
  `camera:` you get the Label3D null-camera fallback (#159) and
  `mapFrom3DScene` silently returns zeros.
- **`Label3D.showLeader` defaults to false** — callouts with leaders
  must opt in.

## QML data-flow traps

- **`Repeater3D` COPIES plain-JS model objects.** Mutating the original
  is invisible to delegates. Bind through an accessor on the root
  (`root.elemAt(id)`) and make every such binding depend on an explicit
  revision counter (`elemRev`) you bump on mutation. Routing through a
  shared `var` property fails *silently*; re-assigning an identical
  object reference emits no change signal. Selection cards need their
  own `elemRev` dependency too — same trap, different surface.
- **`Probe.samples` mutates in place** (`push`/`shift`); bindings on it
  never fire. Consumers listen to `Lab.sampled(t)` instead (Plot2D does).
- **`mapFrom3DScene` bindings freeze when the camera moves** unless they
  list `camera.scenePosition` and `camera.sceneRotation` as explicit
  dependencies. Invisible with a static camera — which is exactly why it
  survives until someone adds an orbit camera. `WorldLabel` already
  carries the fix; prefer it over hand-rolled projections.
- **`font.families` is not a QML font property** — only `font.family`.
  Assigning `families` silently does nothing.
- **Initial QML property values don't fire change handlers** — assign
  entity positions imperatively inside `applyScenario`, or PhysicsItem
  coordinates never sync.
- **Inside a `LabPanel`, `parent` is the panel's stacking column, not the
  panel.** `anchors.fill: parent.body` silently resolves to `undefined`
  and the child gets zero size — a panel that renders as an empty box.
  Bind by id instead: `width: myPanel.body.width`. Anchoring across that
  generation gap is not allowed either (not a parent, not a sibling).
- **A `readonly property alias` cannot be assigned.** Aliasing a lab's
  `watch` onto `monitor.watched` is right, but every old `watch = [...]`
  write then throws at runtime (not at lint time) — route them through
  `setWatched()` / `watchOnly()` / `prune()` / `clear()`.
- **Duplicate property bindings are an error**, so when you re-base a
  Rectangle onto `LabPanel`, delete the `radius`/`color`/`border.*` lines
  the panel already provides.

## Lighting and shadows

- **`shadowBias` is the make-or-break knob**: 3 works; ≥10 pushes thin
  shadows off the surface; 0 floods it with acne — and *both* failures
  look identical to "no shadows" from a distance. Tune by pixel-sampling
  a parameter sweep, never by eye.
- **`shadowMapFar` is camera-relative** and must cover the scene at
  maximum zoom-out (250 for electronics' board, `csmNumSplits: 2`).
- **A huge ground plane starves the shadow map** — shrink the table.
- **Camera-facing line ribbons can never cast shadows** (unshaded
  CustomMaterial is skipped by the shadow pass). Lines that matter lie
  flat on the surface (`orientation: Flat` + `depthBias`) — which also
  buys chevron flow animation.
- **`PointLight.quadraticFade`: LOWER = LESS falloff** = whole-scene
  wash. Bulb-like glows need ~1.2, not 0.015.

## Camera

- The anti-clip rule for an orbit rig is a **minimum camera height above
  the work plane**, not a minimum distance — a distance sphere wrongly
  blocks zooming onto a focused object; a height floor pushes the rig
  outward as pitch flattens and can never end up under the table.
  `OrbitCamera3D` implements this; don't hand-roll.
- A follow camera that feeds `Label3D` sizing must be top-level, not
  nested in a moving rig (`Label3D` reads `camera.position`).

## Publishing to the web

**Every directory a lab imports needs a `qmldir`, or it works on the desktop
and fails in the browser.** A directory import resolves by *listing* the
directory, and a directory cannot be listed over HTTP — so a lab loaded by the
Web Runtime silently loses those types. Two forms bite:

- the kit: `import "../kits/circuit"` → `labs/kits/circuit/qmldir`
- the lab's own siblings: a bare `LidarMonitor { }` next to `Sandbox.qml`
  → `labs/<lab>/qmldir`. This one is easy to miss because there is no import
  statement to remind you; the failure is `LidarMonitor is not a type`.

List every type except `Sandbox.qml` itself (it is loaded by URL). Comments in
a qmldir start with `#` — a `//` comment fails the whole file to parse, and
the error surfaces as "unexpected token" on the *import line*, which sends you
looking in the wrong place entirely. Adding a qmldir is invisible on the
desktop, where Qt scans the directory when none is present.

Related: `.js` imports name a file (`import "../kits/x/y.js" as Y`) and so
work over HTTP untouched — only *directory* imports need the manifest.

Also web-only: a Canvas font must be quoted. `ctx.font = "10px " + family`
silently drops the whole declaration when the family has a space in it, and
the family that gets picked differs between desktop and WASM, so this hides
until you publish.

## Loader / reload semantics

- **Plugin QML is baked into the plugin (rcc): kernel changes need a
  loader RESTART**, not a reload.
- **The loader watches only the sandbox dir** — after kit-file edits,
  request an inspector `reload` explicitly.
- Scenario is applied **before** `applyViewState` on restore (it resets
  clock + RNG); the user's serialized state wins over the preset.
- Live `eval` patches are preview only — every fix lands in source and
  is confirmed through a state-preserving reload.

## Determinism

- **Visualization must never consume the sim RNG stream** — a scan
  display drawing jitter from `clock.random()` changes the physics of
  the next run. Decorative noise uses a hash of stable inputs.
- World-attached clocks advance with physics steps; world-less labs
  **must step per-frame** — advancing sim state in one lump freezes the
  world during sampling (was a real bug). Use `SimClock.fixedStep` +
  `onStepped` rather than hand-rolling an accumulator: it swallows the
  rewind a `reset()` causes, caps the catch-up so a hitch cannot become a
  freeze, and clears its remainder on reset (a carried-over fraction
  would make a replayed run differ from a fresh one).
- **Measure determinism with the clock PAUSED.** The frame ticker keeps
  running between inspector round-trips, so "same seed, same N steps"
  silently compares N and N+30 steps. Pause first, then `time step`, then
  read — otherwise you will chase a determinism bug that is not there.
- `SimClock.wasReset` exists so sensors/estimators snap at scenario
  boundaries instead of blending across a reset.
- A drifting constellation or similar background motion should be a pure
  function of `clock.time`, touching no RNG at all.

## Numbers and UI copy

- Normalize value-to-decade (resistor color bands) **by division, not
  `log10`** — `log10(1000)` lands fractionally under 3 and mis-colors
  the decade.
- German strings run ~25% longer: width-cap and elide every text panel,
  and cap the hint bar against its neighbor panel, not `root.width`.
- `Plot2D.series` semantics: `null` = all registered probes (legacy
  fallback), `[]` = draw the placeholder. An empty watch list must mean
  "nothing to plot" — the fallback-on-empty bug shipped once.
- `DataRecorder` with a relative destination writes into the process
  CWD (repo root, usually) — always set an explicit path.

## Physics / world

- Mapless `ClayWorld2d` requires `components: new Map()`.
- Box2D worlds cannot be re-stepped synchronously: flow checkpoints and
  `viewState` restores in Box2D labs resume from the scenario boundary,
  not the exact frame — state this in the lab's paper if it matters.
