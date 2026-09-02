# Hydro kit — the water analogy, solved the same way

Pumps, valves, narrow pipes and water wheels, solved as a real network
rather than scripted. It is the electricity lesson told in water, and it
is deliberately the *same solver* underneath, so a learner who has met
Ohm's law meets it again wearing different units.

Used by `labs/hydraulics-101/`. Checked by
`node labs/kits/hydro/hydro.test.js`.

## Model card

*A lab card in the sense of a spec sheet: what this kit is a model of, what
it deliberately is not, and therefore which questions it can be asked.*

### What it models

**The steady-state operating point of a network of two-terminal hydraulic
elements, carrying an incompressible fluid in laminar flow.** Pipe runs
merge terminals into *nets* by union-find; each element stamps a
conductance (and, where it has one, a flow source) into the nodal matrix;
`G\,p = q` is solved by **Gaussian elimination with partial pivoting**.
There is no scripting anywhere — a water wheel turns because the solver
says power is flowing through it.

The analogy is exact, term for term, and that is the point:

| electricity | hydraulics | here |
|---|---|---|
| voltage `V` | pressure difference `Δp` | kPa |
| current `I` | volume flow `Q` | L/s |
| resistance `R` = `V/I` | hydraulic resistance `R` = `Δp/Q` | kPa·s/L |
| Ohm's law `V = R·I` | `Δp = R·Q` | the whole model |
| power `P = V·I` | `P = Δp·Q` | W, with **no** conversion factor |
| EMF behind internal resistance | pump head behind `RINT` | why a pump sags |
| Kirchhoff's current law | continuity: what goes in comes out | per-run flow |

The units are chosen so `1 kPa · 1 L/s = 1 W` exactly. Nothing in the code
converts anything.

Element models, with the constants that define them:

| part | model |
|---|---|
| pump | ideal head behind `RINT = 2.0 kPa·s/L`, Norton form; default `P0 = 40 kPa` |
| valve | open `RCLOSED = 0.02`, shut `ROPEN = 1e9` |
| narrow pipe | resistance `max(0.01, value)`; default 8 kPa·s/L |
| water wheel | fixed `RWHEEL = 24.0`, turning above `P_TURN = 0.5 W` |
| flow meter | `RMETER = 0.02`, in line |
| pressure gauge | `RGAUGE = 1e7`, across |
| T-piece | `RCLOSED` between coincident terminals |

Three details are worth naming because they are where a naive
implementation goes wrong:

- **Terminal 0 of a pump is its OUTLET.** Every sign in the file follows
  from that, exactly as the circuit kit's signs follow from "terminal 0 is
  +". The part prints an arrow pointing at that pad, and `parts.js` names
  it in `termNames`.
- **Two pump faults are kept distinct.** A short is the *external
  resistance collapsing to the order of the pump's own*
  (`rExt < 2 · RINT`), not merely a large flow; an overload is
  `|Q| > Q_RATED = 3.0 L/s` without that collapse. Two wheels in parallel
  sit at 12 kPa·s/L at *every* head — never a short, however hard you push.
- **Per-run flow is peeled off by continuity**, not inferred from
  pressure: an ideal connection *is* the net, so both its ends are at the
  same pressure and carry no direction of their own.

### What it deliberately does not

- **Laminar and linear only.** `Δp = R·Q`, a straight line through the
  origin. Real pipe flow above a Reynolds number of about 2300 goes
  turbulent and `Δp` grows roughly with `Q²`; none of that is here. The
  model is the Hagen–Poiseuille regime, which is exactly the regime in
  which the electrical analogy holds.
- **No inertia.** Fluid mass is not represented, so there is no water
  hammer, no surge, no oscillation when a valve slams. The hydraulic
  analogue of an inductor does not exist in this kit.
- **No compressibility and no capacitance.** No air pockets, no
  accumulators, no vessel that stores fluid — the analogue of a capacitor
  is likewise absent.
- **No time at all.** The solver has no clock and no state between calls;
  every result is a steady state. Nothing fills, drains or warms up.
- **No cavitation and no negative-pressure limit.** Pressures are pure
  numbers; the solver will happily report a suction the fluid could not
  survive, and vapour pressure is not modelled.
- **No tanks, no levels, no gravity.** There is no reservoir, no static
  head from height difference, no free surface. The board is flat and
  elevation does not enter the equations.
- **Ideal connections.** A pipe run between two pads has zero resistance
  whatever its length or bore; all resistance lives inside parts. Bends,
  fittings and entry losses are idealised away.
- **The pump has one number.** A real pump has a head-flow curve; this one
  has a constant head behind a constant `RINT`, which is a straight-line
  approximation to it. `Q_RATED` is a stated convention, not a property
  derived from the model, and the pump never cavitates, stalls or wears.
- **The wheel is a resistance, not a rotor.** `RWHEEL` is fixed, there is
  no torque balance, no moment of inertia and no run-up. `speed` is
  `|Q| · RPM_PER_FLOW` — a display scale, honest about being one.
- **A leak conductance `GLEAK = 1e-9` is added to every node** so a
  floating island is solvable. That is numerics, not physics.

### Questions it can be asked

- Where does the pump's head actually go? (`pTerm + internalDrop = p0`,
  measured, exact to 1e-6 — not asserted.)
- Why does a second wheel in *parallel* make the first one slow down,
  while a second wheel in *series* does not?
- What is a short, precisely — and why is "a lot of flow" not the same
  thing?
- What does a flow meter's own resistance cost the measurement?
  (`RMETER` is in the network like anything else.)
- How does closing a valve somewhere change the pressure *everywhere*?
- Is this the same lesson as the circuit lab? (Set `P0/RINT` against
  `EMF/RINT` and compare the two boards' numbers.)

### Questions it cannot be asked

- *"How long until the tank is empty?"* — no tanks, no levels, no time.
- *"What happens when I slam this valve shut?"* — no inertia, so no water
  hammer; the model jumps instantly to the new steady state.
- *"Does this pipe go turbulent?"* — no Reynolds number, no `Q²` term, no
  roughness.
- *"Will the pump cavitate?"* — no vapour pressure and no NPSH.
- *"Does it matter that the wheel sits above the pump?"* — no gravity and
  no static head.
- Anything about a real pump's efficiency, its curve, or its power draw:
  only the delivered `Δp · Q` is modelled.

### What you can vary

- **Topology is the main knob** — series versus parallel versus a bypass
  is a plumbing change, not a parameter.
- **Per-pump head**, 10–120 kPa; every pump carries its own, because head
  is owned by an object.
- **Per-pipe resistance**, walking a preferred-number ladder
  (1, 1.5, 2, 3, 5, 8 per decade up to 1000) — the same convention the
  circuit kit's E12 resistors follow, which is why the default 8 is a rung
  and not a number someone typed.
- **Valve state**, part placement and rotation, T-piece insertion, erase.

### What you can measure

Per element: `q`, `dp`, `power`, `on`, `speed`. Per pump: `p0`, `q`,
`pTerm`, `rExt`, `internalDrop`, `rated`, `shorted`, `overloaded`. Per pipe
run: a signed flow or an honest `null`. Per solve: `netCount` and
`iterations` (always 1 — the model is linear).

## API

- `hydro.js` — `solve(elements, wires)`; helpers `buildNets`,
  `solveLinear`, `resistanceOf`, `conductanceOf`, `attributeWireFlows`,
  `pipeSteps`, `pipeStepOf`. Constants `P0_DEFAULT, RINT, RCLOSED, ROPEN,
  RMETER, RGAUGE, RWHEEL, RPIPE_DEFAULT, GLEAK, Q_RATED, P_TURN,
  RPM_PER_FLOW`.
- `parts.js` — the board contract: `spec` (terminals, footprint, actuator,
  keep-out, fields, card rows), `catalog` (palette order and colours), and
  `specOf`, `terminalCount`, `defaults`, `padAt`, `colorOf`. The pad
  geometry is the circuit kit's, so both kits sit on the same 5-unit peg
  raster.
- `symbols.js` — `draw(ctx, type, cx, cy, w, h, opts)`, ISO 1219 fluid-power
  symbols shared by the palette and any schematic view, so the symbol in
  the list is the symbol in the diagram.
- QML: `HydroElement3D` (same public interface as the circuit kit's
  `CircuitElement3D`, under the domain's names: `simQ`, `simDp`, `turning`),
  `SymbolIcon`, and `Bench` — the kit's own visual test.
- `strings.js` — the kit's EN/DE part vocabulary.

## Tests

```bash
node labs/kits/hydro/hydro.test.js
```

Covers the solver's derivations (series, parallel, dividers), the short
versus overload distinction, the continuity peeling and its honest `null`
for un-attributable runs, the pipe ladder, the board contract in
`parts.js`, and EN/DE key parity.

The visuals have their own check:

```bash
clayrender labs/kits/hydro/Bench.qml --out /tmp/hydro-bench.png \
    --size 1400x900 --settle
```
