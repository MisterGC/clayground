# Kits — what each one is, and how a part is added

A kit owns a domain; a lab owns a situation (`SKILL.md`, *Layout and
boundaries*). Every kit has a README beside its code, and the README is the
contract: model card, API, tests, traps. Read it before you use the kit, and
before you change it.

| kit | README | used by |
|---|---|---|
| circuit | `labs/kits/circuit/README.md` — DC solver, parts, symbols, wire routing, the transistor's anatomy | electronics-101 |
| hydro | `labs/kits/hydro/README.md` — the same solver in water, the valve's anatomy | hydraulics-101 |
| sensor | `labs/kits/sensor/README.md` — three sensors and the solver two share; error produced, not dialled in | sensor-fusion-101 |
| traffic | `labs/kits/traffic/README.md` — road graph, lanes, vehicles | street-network-101 |
| character | `labs/kits/character/README.md` — one kit scene per aspect | character-101 |
| professor | `labs/kits/professor/README.md` — the teacher who flies to a part, points and says a line | electronics-101 |

## Snapshots — what a kit offers

`Lab.snapshot()` holds the clock, the parameters, the probes and a recording
in progress by itself. What a kit's model builds up while time runs it hands
over through a `ModelState` (kernel README, *Snapshots*):

- one per object whose state changes with time, inside the kit's own QML
  type where there is one (`GpsSensor`, `OdometrySensor`, `LidarSensor`
  each carry theirs, named by a `stateName` a lab can change);
- `target` + `properties` for state that is a few assigned properties;
  `save` + `load` for a model in one plain object, or one whose `load` has
  to rebuild something derived (the traffic kit's lane model, from the plan);
- plain data only, and properties the model assigns, never bound ones;
- nothing for a part of the model that is a pure function of `clock.time`
  and the parameters — the hydro and circuit solvers keep nothing over
  time, so their labs offer the board alone.

Check it the way `tools/lab-sweep/tests/run_snapshot_test.py` does: a run
restored half-way and finished writes the record a straight run writes,
byte for byte.

## The professor

A lab that wants someone to teach its flow drops a `Professor` into its
`View3D` and hands the flow to it with a `FlowGuide`; the kit owns how it
behaves, the lab only says where things are. The README has the calls
(`appear`, `travelTo`, `pointAt`, `presentAt`, `tell`, …), how a flow is
narrated, how the camera follows the beat, pre-rendered narration clips,
directed steps, marks, and its traps — the raised-arm silhouette is a
hard constraint. electronics-101 (`Professor {` and `FlowGuide {` in its
`Sandbox.qml`) is the working example. What the professor says is a
lesson's job: `teaching.md`.

## Adding a part to a kit, from the model to the scenario

The circuit kit and electronics-101 are the example; the hydro kit has the
same files under the same names (`hydro.js`, `parts.js`, `symbols.js`,
`HydroElement3D.qml`, `strings.js`). Work in this order — each step has a
check before the next, and the first three never open a lab.

1. **The model** (`circuit.js`, pure JS). Give the part its physics: its
   conductance in `conductanceOf`, any source or companion in
   `stampNetwork`, its terminal count in `TERMINALS` when it is not two.
   A part with discrete states (a diode's on/off, a transistor's region)
   joins the assume-solve-re-check loop rather than getting a rule of its
   own. Terminal 0 is part of its identity (anode, plus, collector) —
   say which is which in the comment at the top of the file.
2. **Its tests** (`circuit.test.js`), now: a `K.section` with the derived
   value the part exists for, checked with `K.near` against the number
   worked out by hand, and the case where it must not conduct. Add the
   part's row to the model card in the kit's README — what it models, its
   constants, and what it deliberately does not do. Check:
   `node labs/kits/circuit/circuit.test.js`.
3. **The board contract** (`parts.js`). An entry in `spec` — pads in the
   part's own frame, body half-extents, actuator, the three `fields`
   (`value`, `on`, `func`), the card `rows` it offers — and one in
   `catalog`, which is the palette's order and the part's colour on the
   board. Pads, hit test and visual are all drawn from these numbers, so
   they are the only place they are written.
4. **The look.** A branch in `CircuitElement3D.qml`
   (`visible: root.type === "<type>"`), its identity printed on it, real
   conventions over decoration; its IEC symbol in `symbols.js` `draw`
   (and `aspect`/`leadFractions` when its leads do not meet the box like
   a two-pad part's), so the palette and the schematic show the same
   symbol. A new QML file in the kit is also a line in the kit's
   `qmldir`.
5. **The words** (the kit's `strings.js`, EN and DE together):
   `part.<type>`, `part.<type>.hint`, `code.<type>`.
6. **The lab.** Find every place the lab switches on a type and decide
   for each whether the part needs a branch: electronics-101 has them in
   `solverElements()` (a field the lab does not pass on never reaches the
   solver), the card (`cardTitle`, its rows, its hint), the schematic's
   `plan*` functions and `scriptTypes` (what a narration line may call
   it). A part with state the learner sets gets a control on its card,
   never a lab-wide `Parameter`.
7. **The scenario.** A `Scenario { name; script }` that builds the
   situation the part is for with the lab's own verbs (`addElement`,
   `addWire`), and `scenario.<name>` plus `scenario.note.<name>` in the
   lab's `strings.js`, EN and DE. A tenth scenario on has no digit key
   (`SKILL.md`, key map), so place it after the ones a learner meets
   first.
8. **Records and the gate.** A model change invalidates every committed
   record: rerun `records/make.sh` and the studies' sweeps, commit the new
   records, re-read every number the paper quotes, and run
   `tools/lab-check/lab-check labs/<lab>` (`check-failures.md` when it is
   red).
