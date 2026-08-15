# Circuit kit — a school kit that obeys Kirchhoff

Parts you can place and wire, solved as a real network rather than
scripted. The kit owns the electricity; the lab owns the bench.

Used by `labs/electronics-101/`. Checked by
`node labs/kits/circuit/circuit.test.js`.

## Model card

*A lab card in the sense of a spec sheet: what this kit is a model of, what
it deliberately is not, and therefore which questions it can be asked.*

### What it models

**The steady-state DC operating point of a network of two-terminal
elements.** Wires merge terminals into *nets* by union-find; each element
stamps a conductance (and, where it has one, a current source) into the
nodal matrix; `G\,v = i` is solved by **Gaussian elimination with partial
pivoting**. There is no scripting anywhere — a bulb lights because the
solver says power is flowing through it.

Element models, with the constants that define them:

| part | model |
|---|---|
| battery | ideal EMF behind `RINT = 0.5 Ω`, Norton form; default 4.5 V |
| resistor | conductance `1 / max(0.1, R)`; default 470 Ω |
| bulb | fixed `RBULB = 6.0 Ω`, lit above 5 mW |
| LED | piecewise-linear diode: open below `VF = 2.0 V`, then `RLED = 15 Ω` |
| switch | `RCLOSED = 0.01 Ω` / `ROPEN = 1e9 Ω` |
| ammeter / voltmeter | `RSHUNT = 0.01 Ω` / `RVOLT = 1e7 Ω` |
| junction | a solder dot: `RCLOSED` between coincident terminals |

Three details are worth naming because they are where a naive
implementation goes wrong:

- **The LED's nonlinearity is resolved by iterating over conducting
  states** (assume, solve, re-check; `maxIter = 12`, typically ≤ 2), with a
  flip-lock after three oscillations for the case where leakage behind an
  open switch fakes a forward bias.
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
- **The LED is piecewise linear, not Shockley.** A hard knee at `VF` then a
  constant 15 Ω slope. No soft turn-on, no temperature dependence — and
  **reverse breakdown is not modelled**: a reversed LED is simply open.
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
- **Non-convergent LED configurations are decided by fiat**, not physics:
  more than three state flips pins the LED off inside the 12-iteration cap.
  Defensible for dead branches, a heuristic nonetheless.
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
  wiring change, not a parameter.
- **Per-cell voltage**, 1.5–12.0 V in 0.5 V steps.
- **Per-resistor resistance**, walking the real **E12 series**
  (10, 12, 15, 18, 22, 27, 33, 39, 47, 56, 68, 82 × 1/10/100, plus 10 kΩ) —
  the actual convention, not a slider.
- **Switch state**, part placement and rotation, junction insertion, erase.

Note there is deliberately **no global battery parameter**: every cell
carries its own voltage, because voltage is owned by an object.

### What you can measure

Per element: `v`, `i`, `on`, `power`. Per battery: `emf`, `i`, `vTerm`,
`rExt`, `internalDrop`, `rated`, `shorted`, `overloaded` — with
`vTerm + internalDrop = emf` exact to 1e-6. Per wire: a
signed current or an honest `null`. Per solve: `netCount` and `iterations`.

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

### Questions it cannot answer

- Anything with a capacitor, an inductor, or a waveform.
- *"Will this LED survive?"* — no thermal model, no reverse breakdown.
- *"How long will the battery last?"* — no capacity, no discharge.
- *"Why does my breadboard circuit not work?"* — contact resistance, wire
  resistance and tolerance are all idealised away.

## API

- `circuit.js` — `solve(elements, wires)`; helpers `buildNets`,
  `solveLinear`, `conductanceOf`, `attributeWireCurrents`. Constants
  `RINT, RCLOSED, ROPEN, RSHUNT, RVOLT, RBULB, RLED, VF_LED, GLEAK, I_RATED`.
- `symbols.js` — `draw(ctx, type, cx, cy, w, h, opts)`, IEC 60617 symbols
  shared by the palette and the schematic view, so the symbol in the list is
  the symbol in the diagram.
- QML: `CircuitElement3D`, `SymbolIcon`.
- `strings.js` — the kit's EN/DE part vocabulary.

## Tests

```bash
node labs/kits/circuit/circuit.test.js
```

Covers the solver's derivations (series, parallel, dividers), the short
versus overload distinction, LED convergence and the honest `null` for
un-attributable wires.
