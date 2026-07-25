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
- **ParamPanel** — auto-generated slider panel for all parameters.
- **Plot2D** — live autoscaled strip chart of probes. Pass `probes` for a
  fixed set, or `series: [{probe, label, color}]` when the plotted set is
  built at runtime: the lab then owns naming and colouring, an empty array
  draws `placeholder` instead of every probe, and legend entries become
  clickable (`seriesClicked`) so the user can drop a curve where it is named.
- **DataRecorder** — probe samples to CSV (via `Clayground.Text`).
- **LabLang / LangSwitch** — runtime language switch for a published lab.
  Whoever owns a vocabulary registers it (`LabLang.register(dict)` with
  `{lang: {key: text}}`), strings are ordinary bindings on `LabLang.t(key)`
  / `tf(key, ...)`, and `LabLang.num(v, digits)` prints numbers in the
  language's notation (German gets a decimal comma; `Plot2D`, `BudgetBar`
  and `ParamPanel` already use it). Not `qsTr`: retranslating a live engine
  is a C++ call on the `QQmlEngine`, which a lab hosted by the dojo or
  exported to WASM does not own. Drop `LangSwitch` in a corner and it
  offers exactly the registered languages.
- **Scenario / ScenarioSet** — named, scripted situations wiring the
  `scenarios()`/`applyScenario()` inspector convention; applying resets
  the clock so runs are reproducible.

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

See `demo/Sandbox.qml` (kernel-only damped oscillator) and
`labs/physics-playground/` for a full physics-based lab.
