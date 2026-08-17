# Circuit kit — a school kit that obeys Kirchhoff

Parts you can place and wire, solved as a real network rather than
scripted. The kit owns the electricity; the lab owns the bench.

Used by `labs/electronics-101/`. Checked by
`node labs/kits/circuit/circuit.test.js`.

## Model card

*A lab card in the sense of a spec sheet: what this kit is a model of, what
it deliberately is not, and therefore which questions it can be asked.*

### What it models

**The steady-state DC operating point of a network of two-, three- and
five-terminal elements.** Wires merge terminals into *nets* by union-find;
each element stamps a conductance (and, where it has one, a current source)
into the nodal matrix; `G\,v = i` is solved by **Gaussian elimination with
partial pivoting**. There is no scripting anywhere — a bulb lights because
the solver says power is flowing through it, and a gate answers because the
solver says so, not because a truth table was written down.

Element models, with the constants that define them:

| part | model |
|---|---|
| battery | ideal EMF behind `RINT = 0.5 Ω`, Norton form; default 4.5 V |
| resistor | conductance `1 / max(0.1, R)`; default 470 Ω |
| bulb | fixed `RBULB = 6.0 Ω`, lit above 5 mW |
| diode | piecewise-linear: open below `VF_DIODE = 0.7 V`, then `RDIODE = 10 Ω` |
| LED | the same diode with a higher knee: `VF_LED = 2.0 V`, `RLED = 15 Ω` |
| switch | `RCLOSED = 0.01 Ω` / `ROPEN = 1e9 Ω` |
| transistor | NPN, three terminals (0 collector, 1 base, 2 emitter) — below |
| gate | a logic package, five terminals (0 VCC, 1 A, 2 B, 3 Y, 4 GND) — below |
| ammeter / voltmeter | `RSHUNT = 0.01 Ω` / `RVOLT = 1e7 Ω` |
| junction | a solder dot: `RCLOSED` between coincident terminals |

**The NPN transistor** is piecewise linear in the three regions a school
course names, and which one it is in is solved for, never assumed:

| region | base-emitter | collector-emitter |
|---|---|---|
| `off` | `R_BE_OFF = 1e7 Ω` | `R_CE_OFF = 1e8 Ω` |
| `active` | diode: `VF_BE = 0.7 V` then `R_BE = 25 Ω` | current source `BETA · Ib`, with `R_EARLY = 1e5 Ω` across it |
| `sat` | the same diode | `VCE_SAT = 0.15 V` then `R_SAT = 4 Ω` |

`BETA = 100`. The base-emitter branch is the *same companion the diodes
use*, which is why a base current comes out of the network rather than out
of a rule: put 4.7 kΩ in front of the base and the base current is what
that resistor allows. The active region's collector source is the one
**asymmetric** stamp in the solver — a current between two nets that
depends on the voltage across two *others* — and the reason `G` is solved
by plain elimination rather than by anything assuming symmetry.

**The logic gate** is the one *behavioural* part in the kit, and it is
modelled as a **package** rather than as a function. Its `func` is one of
`and` / `or` / `xor` / `nand` / `nor` / `not` (`not` uses A and ignores B,
whose pad still exists). What makes it electronics rather than algebra is
that it has real supply pins and its output is **pushed onto whichever pad
it was actually given**:

| | |
|---|---|
| inputs | `R_GATE_IN = 1e6 Ω` from each input pad to the GND pad, so a floating input reads low |
| supply | `R_GATE_Q = 1e5 Ω` VCC→GND, the quiescent draw of a chip doing nothing |
| threshold | ratiometric: an input is high above `vcc/2`, so the part works at any supply |
| output | push-pull, `R_GATE_OUT = 50 Ω` to the VCC net or the GND net |
| unpowered | below `V_GATE_MIN = 0.5 V` the output is high-impedance and the gate answers nothing |

The output level is a discrete state (`hiz` / `low` / `high`) resolved on
the same assume-solve-re-check loop the diodes and the transistor use, so a
chain of gates settles by itself and nothing about the composition is
scripted. Unwire VCC and the gate stops working, because there is no
invented supply anywhere in the model to fall back on.

Four details are worth naming because they are where a naive
implementation goes wrong:

- **Non-linear parts are resolved by iterating over their discrete
  states** (assume, solve, re-check; `maxIter = 40`, 1–7 in the shipped
  scenarios), with a flip-lock after six oscillations for the case where
  leakage behind an open switch fakes a forward bias.
- **Cut-off leakage sits decades below an open contact.** `R_BE_OFF` is
  1e7 against a switch's 1e9 for a reason: with both at 1e9, a base
  reached only through an open switch sits on a 1:1 divider, half the
  supply lands on it, and a transistor whose input is *disconnected*
  switches itself on. Real silicon leaks tens of nanoamps while a real
  open contact leaks nothing measurable.
- **Two battery faults are kept distinct.** A short is the *external
  resistance collapsing to the order of the cell's own*
  (`rExt < 2 · RINT`), not merely a large current; an overload is
  `|i| > I_RATED = 1.5 A` without that collapse. Two 6 Ω
  bulbs in parallel sit at 3.01 Ω at *every* voltage — never a short,
  however hard you push.
- **Per-wire current is peeled off by KCL**, not inferred from potential: an
  ideal wire *is* the net, so both its ends are at the same voltage and
  carry no orientation of their own.

### Deliberate simplifications

- **DC only.** No capacitors, inductors or AC sources — the solver has no
  notion of time or frequency. Nothing transient is representable: no RC
  charging, no inrush, no filtering.
- **Ideal wires.** Zero resistance; wire length and gauge have no electrical
  consequence at all. All contact resistance lives inside parts.
- **Diodes are piecewise linear, not Shockley.** A hard knee at `VF` then a
  constant slope. No soft turn-on, no temperature dependence — and
  **reverse breakdown is not modelled**: a reversed diode or LED is simply
  open.
- **The transistor is a switch with a gain, not a device model.** `BETA` is
  a constant: it does not fall off at high current, does not vary with
  temperature, and does not differ between two parts. There is no
  base-collector capacitance and therefore **no switching speed** — a gate
  here settles instantly, so propagation delay, fan-out limits and race
  conditions are all outside it. Saturation is a fixed
  `VCE_SAT` + `R_SAT` rather than a curve, and reverse-active operation
  (collector below emitter) falls out of the saturation companion rather
  than being modelled.
- **Only NPN.** No PNP, no FET, so complementary and CMOS logic cannot be
  built here at all.
- **The gate is behavioural, and deliberately so.** It is a threshold, a
  boolean and a 50 Ω output — not a transistor network, and not a real
  logic family. No propagation delay, no input current beyond the 1 MΩ
  pull-down, no output current limit, no noise margin worth the name, and
  no distinction between TTL and CMOS. It is the level of abstraction at
  which "two of these make an adder" is the interesting sentence; if the
  question is *how* a gate is made, the transistor presets are the honest
  answer and the gate is not.
- **The bulb's resistance is constant.** A real filament climbs several-fold
  as it heats, so true cold-inrush and warm-running currents differ; here
  they do not. Brightness is read straight off dissipated power.
- **Cells are ideal apart from `RINT`.** They do not sag and never run down;
  there is no capacity and no discharge curve. `I_RATED = 1.5 A` is a stated
  convention, not a property derived from the model.
- **A leak conductance `GLEAK = 1e-9` is added to every node** so a floating
  island is solvable. That is numerics, not physics — and it is the reason a
  disconnected LED can see a fake forward bias.

### Where it stops being valid

- **Anything time- or frequency-dependent is out of scope entirely** —
  filters, oscillators, switching transients, power factor.
- **Near and below the LED knee the model is a cliff.** A diode biased just
  under `VF` shows exactly 0 mA where a real one shows leakage; the
  turn-on region cannot be studied here.
- **A feedback loop between gates does not settle.** Wire an output back to
  an input and the state iteration oscillates until the flip-lock pins it.
  That is the sequential limit above, arriving as a symptom: there is no
  time in the model, so a latch has nothing to latch.
- **Non-convergent configurations are decided by fiat**, not physics: more
  than six state flips pins a part where it stands, inside the
  40-iteration cap. Defensible for dead branches, a heuristic nonetheless.
- **A transistor sitting exactly on its knee is reported as conducting
  with no current.** In a stack whose lower transistor is off, the upper
  one's emitter floats up until `Vbe` lands on `VF_BE`; the model then
  calls it saturated while `Ib` and `Ic` are both zero. That is the right
  answer about the *circuit* — nothing can flow — but the region label at
  that operating point is a knife edge, not a measurement.
- **Redundant wiring is honestly un-attributable.** Two wires in parallel
  between the same terminal pair leave `wireCurrent === null` rather than an
  invented split. Only tree-shaped wiring resolves completely.
- **Conditioning sets the usable span.** With `ROPEN`/`RVOLT` at 1e9/1e7 Ω
  against `GLEAK` at 1e-9 S, readings are meaningful roughly between 1e-9
  and 1e9 Ω. Resistances below 0.1 Ω silently clamp.
- **A singular network returns `ok: false`** with no per-element results
  rather than a plausible-looking answer.

### What you can vary

- **Topology is the main knob** — series versus parallel versus short is a
  wiring change, not a parameter. With transistors that goes further: two
  in series is an AND at the lamp, the same two in parallel is an OR, and
  neither is a setting anywhere.
- **A gate's function**, `and` / `or` / `xor` / `nand` / `nor` / `not`,
  set per package. The one place in the kit where logic *is* a setting —
  which is exactly what buying a chip gets you.
- **Per-cell voltage**, 1.5–12.0 V in 0.5 V steps.
- **Per-resistor resistance**, walking the real **E12 series**
  (10, 12, 15, 18, 22, 27, 33, 39, 47, 56, 68, 82 × 1/10/100, plus 10 kΩ) —
  the actual convention, not a slider.
- **Switch state**, part placement and rotation, junction insertion, erase.

Note there is deliberately **no global battery parameter**: every cell
carries its own voltage, because voltage is owned by an object.

### What you can measure

Per element: `v`, `i`, `on`, `power`. Per gate, on top of that: `func`,
`vcc`, `a`, `b`, `y`, `powered`, and `term[0..4]` — the current leaving
each of its five pins, which is what lets the wire attribution treat a
five-terminal part like any other. Per transistor, on top of that:
`mode` (`off` / `active` / `sat`), `ib`, `ic`, `vbe`, `vce` — and its `v`
and `i` are the collector-emitter pair, so every generic readout in a lab
reads a transistor without knowing what one is. Per battery: `emf`, `i`,
`vTerm`, `rExt`, `internalDrop`, `rated`, `shorted`, `overloaded` — with
`vTerm + internalDrop = emf` exact to 1e-6. Per wire: a signed current or
an honest `null`. Per solve: `netCount` and `iterations`.

### Questions it can answer

- Where does the EMF actually go? (Terminal voltage plus internal drop,
  measured, not asserted.)
- How do series and parallel divide current and voltage, and what does
  adding a branch do to the *rest* of the circuit?
- What is a short, precisely — and why is "a lot of current" not the same
  thing?
- What does an ammeter's own resistance cost the measurement?
  (`RSHUNT` is in the network like anything else.)
- Why does an LED need a series resistor, and what happens without one?
- How much current does a base have to supply to command a given collector
  current, and what changes when the collector branch cannot take
  `BETA · Ib`? (That is the whole active/saturated distinction.)
- What does a gate built out of these parts actually do — for every
  combination of its inputs? Each row is a fresh solve, so the answer is a
  measurement of the circuit rather than a table someone typed.
- Why does a floating input not behave like a low one?
- What does a gate cost when it is doing nothing? (Quiescent current is in
  the network, so it shows up in the cell's total like any other load.)
- What happens to a chip whose supply is not connected — and why is that
  different from one whose inputs are low?
- What does a composition of gates do? Wire one output into the next
  input, and the answer settles out of the network rather than out of a
  boolean expression somebody wrote down.

### Questions it cannot answer

- Anything with a capacitor, an inductor, or a waveform.
- *"How fast is this gate?"* — there is no time in the model at all, so
  propagation delay, rise time, glitches and race conditions do not exist
  here. **Anything sequential is therefore out of reach**: a flip-flop
  wired up in this kit has no defined state, because the feedback loop it
  depends on is exactly the transient the solver has no notion of.
- *"How many gates can this one drive?"* — fan-out is a loading and timing
  question, and only the loading half is represented.
- *"Will this LED (or this transistor) survive?"* — no thermal model, no
  reverse breakdown, no maximum ratings.
- *"How long will the battery last?"* — no capacity, no discharge.
- *"Why does my breadboard circuit not work?"* — contact resistance, wire
  resistance and tolerance are all idealised away.

## API

- `circuit.js` — `solve(elements, wires)`; helpers `buildNets`,
  `solveLinear`, `conductanceOf`, `stampNetwork`, `stateFrom`,
  `attributeWireCurrents`, `terminalCount`, `diodeSpec`. Constants
  `RINT, RCLOSED, ROPEN, RSHUNT, RVOLT, RBULB, RLED, VF_LED, RDIODE,
  VF_DIODE, BETA, VF_BE, R_BE, VCE_SAT, R_SAT, R_EARLY, R_BE_OFF,
  R_CE_OFF, R_GATE_IN, R_GATE_Q, R_GATE_OUT, V_GATE_MIN, GLEAK, I_RATED`.
- `route.js` — `routeAll(links, obstacles, grid)` and `routeOne(a, b,
  obstacles, taken, grid)`, plus the path arithmetic a caller needs to
  interpret what came back: `pathLength`, `midOfPath`, `closestOnPath`,
  `clean`, `occupancy`, `scorePath`. See *Wire routing* below.
- `plan.js` — laying a diagram out on a sheet: `fitBox(pts, box, pad)` for the
  uniform fit, `placeLabels(anchors, opts)` for lettering that dodges the
  symbols, the wires and the other labels, plus `overlaps`, `collides`,
  `textBox` and `readable`. See *Lettering a diagram* below.
- `symbols.js` — `draw(ctx, type, cx, cy, w, h, opts)`, IEC 60617 symbols
  shared by the palette and the schematic view, so the symbol in the list is
  the symbol in the diagram. Plus `aspect(type)` and `leadFractions(type)`:
  a symbol's box is not a bounding box, it is defined by where the leads meet
  its edge, so a caller drawing symbols **next to real wires** has to size the
  box from the part's actual pad separation. Get that wrong and the wire stops
  at the pad while the lead stops somewhere else — a diagram with gaps in it.
- QML: `CircuitElement3D`, `SymbolIcon`.
- `strings.js` — the kit's EN/DE part vocabulary.

## Wire routing

A wire is drawn as a Manhattan path, not as the straight line between its two
pads. `route.js` has no electrical content at all — it is told where the pads
are, which way each lead leaves its pad, and where the part bodies are, and it
answers with a list of points.

Three rules, in the order they decide:

1. **A lead leaves along its pad's own side.** The direction comes from the
   pad's offset from the middle of the part, so a resistor's wire leaves the
   end of the resistor and a transistor's base lead leaves the base side. A
   solder dot has no side and may be left on either axis.
2. **Two pads already in line get the straight wire** — unless a part is
   standing in that lane, or another wire is already running along it.
3. **Otherwise the turning point is chosen by score.** Candidate paths are
   generated (one corner where the two leads are on different axes, two where
   they are on the same one, four to step over something in the way), and the
   cheapest wins: crossing a part costs `COST_HIT`, entering a pad from the
   wrong side `COST_BACK`, each corner `COST_BEND`, each unit hidden under an
   already-routed wire `COST_SHARE`, and length costs one per unit.

Candidate turning points are the midpoint, a few pegs either side of it, the
two ends of the leads, and the sides of the parts nearby — the last of these
is what lets a route pass a part by a hair rather than missing it by one.

Wires are routed as a board rather than one at a time, because a wire has to
know which lanes are already taken; the order of the list therefore decides
who gets a lane and who goes round. Same board in, same paths out.

What it does **not** do: it does not move parts, it does not re-route to
untangle crossings (two wires crossing is normal and is drawn as a crossing),
and it has no global optimum — it is a scored local choice per wire.

## Lettering a diagram

A schematic the size of a postage stamp can only show the *shape* of a
circuit. Given a whole window there is room to name every part and print what
it is rated at — and then the question stops being "what does the circuit look
like" and becomes "where does the text go", which is what `plan.js` answers.

`fitBox` is the uniform fit: a set of points in board cells into a box in
pixels, with a margin. In the maximised diagram that margin is not decoration,
it is where the outermost parts' labels live.

`placeLabels` is the interesting half. Each anchor carries where its symbol is,
how big the symbol is, and how big its label block is; each label is then given
the first of four sides (below, above, right, left) on which it does not cover
a symbol, a label already placed, or anything in the caller's `avoid` list —
which is how the lab keeps text off its wires. A label with nowhere clear to go
comes back `placed: false` at its first choice, so the caller decides between
dropping it and drawing it over something; the lab draws it on a small card,
which is what a draughtsman does with a note that must sit over a conductor.

Deterministic and order-sensitive by design: earlier anchors win a contested
spot, so the same board always letters the same way.

## Tests

```bash
node labs/kits/circuit/circuit.test.js
node labs/kits/circuit/route.test.js
node labs/kits/circuit/plan.test.js
```

The solver suite covers its derivations (series, parallel, dividers), the
short versus overload distinction, diode convergence and the honest `null` for
un-attributable wires — and the transistor: its three regions, the current
gain measured in the active one, the cut-off a disconnected base must give,
and the full truth table of every gate the lab ships, built out of the same
element list the lab passes in.

The plan suite covers the fit landing every point inside its box (including the
degenerate boards - no parts, one part, every part in the same place), and the
lettering: no label on a symbol, no label on another label, none outside the
sheet, the contested-spot order, and a deliberately crowded grid where some
labels must honestly report that they did not fit.

The router suite covers the property that makes it a Manhattan router at all
(every segment axis-aligned, on every board it is given), that leads leave and
arrive on their pads' own sides, that pads already in line still get the
straight wire, that a blocked lane is gone round rather than through, and that
the path arithmetic the hit test and the junction drop rely on agrees with the
path that was drawn.
