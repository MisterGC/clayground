# Electronics 101 — a school kit that obeys Kirchhoff

*Companion paper to the interactive lab in `labs/electronics-101/`.
Overview board: `overview.grafli`. Annotate freely with CriticMarkup —
remarks feed the next lab iteration.*

## The question

Every school electronics set makes the same promise: snap a battery, a
switch and a lamp together and the lamp lights. What the plastic parts
never show is *why* — why two bulbs in series glow dim while the same two
in parallel blaze, why a resistor tames an LED, why one careless wire
from plus to minus is a short. This lab puts the kit on a 3D pegboard and
runs a real circuit solver underneath it: you drag parts out of the
palette, wire terminals by clicking two gold spheres, flip the switch,
and every LED, bulb and meter answers with the number Kirchhoff's laws
demand. The board is a toy; the physics is not.

## The solver

The lab solves the board as a DC resistive network by **nodal analysis**
(`labs/kits/circuit/circuit.js`). Every part has two terminals; wires
merge terminals into **nets** with union-find, so a net is one electrical
node. With $n$ nets the unknowns are the node voltages
$\mathbf{v} = [v_0, \dots, v_{n-1}]^T$, and Kirchhoff's current law at
every node is one linear system:

$$
G\,\mathbf{v} = \mathbf{i}
$$

$G$ is the $n \times n$ conductance matrix, $\mathbf{i}$ the vector of
injected currents. Each element is a **Norton companion** — a conductance
$g$ in parallel with an optional current source — stamped between its two
nets $a$ and $b$ by the same four-entry pattern:

$$
G_{aa}\mathrel{+}= g,\quad G_{bb}\mathrel{+}= g,\quad
G_{ab}\mathrel{-}= g,\quad G_{ba}\mathrel{-}= g
$$

A plain resistor stamps $g = 1/R$ and no source. The **battery** is an
ideal source $V$ behind an internal resistance $R_\mathrm{int}=0.5\,\Omega$;
its Norton form is a conductance $1/R_\mathrm{int}$ plus a current source
$V/R_\mathrm{int}$ pushed into the $+$ terminal. A closed **switch** is
$0.01\,\Omega$, an open one $10^9\,\Omega$; the **ammeter** is a
$0.01\,\Omega$ shunt, the **voltmeter** a $10\,\mathrm{M}\Omega$ load; a
**bulb** is a fixed $6\,\Omega$ filament. A tiny leak conductance
($10^{-9}$) anchors every net to ground so that a disconnected island is
still a solvable system rather than a singular matrix. The assembled
$G\,\mathbf{v}=\mathbf{i}$ is solved by Gaussian elimination with partial
pivoting.

The **LED** is the one nonlinear part, modeled piecewise-linear rather
than by the full Shockley exponential:

$$
I_\mathrm{LED} =
\begin{cases}
0 & V \le V_F \\[2pt]
\dfrac{V - V_F}{R_\mathrm{LED}} & V > V_F
\end{cases}
\qquad V_F = 2.0\,\mathrm{V},\ R_\mathrm{LED} = 15\,\Omega
$$

Below the forward voltage the diode is an open circuit; above it, it
conducts along a straight line of slope $1/R_\mathrm{LED}$. In the
conducting branch that line is itself a Norton companion — conductance
$1/R_\mathrm{LED}$ with a current source $V_F/R_\mathrm{LED}$ into the
anode — so it stamps like everything else. Because whether an LED
conducts depends on the very voltages the solve produces, the solver
iterates: assume each LED's state, build and solve $G\,\mathbf{v}=\mathbf{i}$,
re-check each LED, repeat until the states stop changing. An LED that sits
in a branch which cannot carry current (behind an open switch, where the
leak dividers fake a faint forward bias) would flip on/off forever; a
flip counter pins it **off** after a few oscillations — the physically
correct answer — inside a 12-iteration cap. On every scenario here the
fixed point is reached in **≤ 2 iterations**.

That iteration *is* the lesson made mechanical: current does not flow
because a wire exists, it flows because the node voltages, solved all at
once, leave a forward drop across a part that will pass it.

## Stated simplifications

- **DC only.** No capacitors, inductors or AC sources — the solver has no
  notion of time or frequency, only a steady operating point.
- **Ideal wires.** A wire has exactly zero resistance; it merges two
  terminals into one net. All contact resistance lives in the parts
  (closed switch and ammeter at $0.01\,\Omega$), never in the wiring.
- **LED as piecewise-linear.** A hard knee at $V_F$ then a constant
  $15\,\Omega$ slope, not the smooth Shockley $I = I_S(e^{V/nV_T}-1)$.
  Reverse breakdown is not modeled — a reversed LED is simply open.
- **Constant bulb resistance.** The filament is a fixed $6\,\Omega$; a
  real incandescent's resistance climbs several-fold as it heats, so its
  true cold-inrush and warm-running currents differ. Brightness here is
  read straight off dissipated power.
- **One global battery voltage.** Every battery on the board reads the
  same `batteryV` slider; you cannot yet set two different cells.

## Measured results

Default board, `batteryV = 4.5 V`, read live off the running lab
(the solver also carries a 19-case node unit suite — Ohm's law, switch
open/closed, LED forward and reversed-dark, series/parallel bulbs, short
detection, meter readings, floating elements, parallel-LED current
sharing):

| scenario | battery current | per-element reading | result |
|---|---|---|---|
| **led-basic** (470 Ω + LED), switch open | 0 mA | everything 0 mA | dark |
| **led-basic**, switch closed | 5.15 mA | LED 5.15 mA · $V_\mathrm{LED}$ 2.08 V · ammeter 5.1 mA | LED lit |
| **series** (two 6 Ω bulbs) | 360 mA | 360 mA through both · 0.78 W each | both dim |
| **parallel** (two 6 Ω bulbs) | 1282 mA | 641 mA per bulb · 2.47 W each | both near-full |
| **reversed LED** (anode to −) | 0 mA | pinned off | dark |
| **dead short** (wire + to −) | 9 A | — | short flag · red battery · banner |

Readings worth chasing to their equations. The lit LED draws

$$
I = \frac{V - V_F}{R + R_\mathrm{LED} + R_\mathrm{int} + 2R_\mathrm{shunt}}
  = \frac{4.5 - 2.0}{470 + 15 + 0.5 + 0.02} = 5.15\,\mathrm{mA},
$$

and the voltmeter across it reads $V_F + I\,R_\mathrm{LED} =
2.0 + 0.00515 \times 15 = 2.08\,\mathrm{V}$ — the knee plus the drop on
the internal slope. The dead short is limited only by the battery's own
$0.5\,\Omega$: $4.5 / 0.5 = 9\,\mathrm{A}$, which trips the
$1.5\,\mathrm{A}$ short flag.

The headline is the series-versus-parallel pair. **Same two bulbs, same
battery, only the wiring differs**, yet the battery delivers 360 mA in
series and 1282 mA in parallel — roughly $3.5\times$. Series stacks the
resistances ($0.5 + 6 + 6$) so the shared current is small and both bulbs
barely glow; parallel halves them ($0.5 + 3$) so each bulb gets nearly
the full cell and blazes. That contrast, produced by rewiring alone, is
the core physical lesson of the lab.

## Things to try

- **Push the LED to its ceiling.** Swap in a 100 Ω resistor and crank
  `batteryV` to 12 V. The current climbs but the LED clamps near its
  $V_F$ knee — most of the extra volts now burn in the resistor, not the
  diode. Watch `iLed` flatten on the plot as you drag the slider.
- **Build both bulb circuits and compare.** Press `2`, read the battery
  current, press `3`, read it again. Feel the $3.5\times$ jump — then
  notice the parallel bulbs are the bright ones. Same parts, different
  wiring, different physics.
- **Reverse an LED on purpose.** Wire its anode (the gold foot) to minus.
  It stays dark at exactly 0 mA. Polarity is real, not decorative.
- **Meter a divider.** Load the `metering` preset (`4`): the ammeter sits
  in series and reads loop current, the voltmeter sits across the LED and
  reads its drop. Cycle the resistor (click it) and watch both readings
  move together.
- **Make a short.** Run a single wire straight from $+$ to $-$. 9 A, the
  battery flashes red, the banner drops. Now put a resistor in that wire
  and watch the short clear — that is what a resistor is *for*.

## Run it

```bash
./build/bin/claydojo --sbx labs/electronics-101/Sandbox.qml
```

Keys: `1` led-basic · `2` series · `3` parallel · `4` metering ·
`E` eraser · `C` clear · `#` grid mode · `R` turn the selected part ·
`Del` remove it · `F` frame it · `0` reset the view · `Esc` cancel ·
`Shift+R` record CSV.

Drag parts from the palette onto the board, click two gold terminals to
wire, click a switch to flip it, click a resistor to cycle its ohms, drag
a part to move it. Every preset starts with the switch **open** — flipping
it is the invitation.

Clicking a part **selects** it: a frame is drawn around it on the paper
(with a nose mark showing which way it faces) and a card reports its
voltage and current. `R` or a right-click turns it in 90° steps — wires
follow the terminals. Moving is grid-snapped by default, exactly like
grafli's grid mode: the pegs are drawn as small squares while snapping and
as round dots when parts move freely, `#` cycles the mode and holding `Alt`
inverts it for one drag. The peg raster is 5 world units — half a part
width — so snapped parts can still be nudged in fine steps; `cellFree`
therefore keeps two pegs of clearance around every part.

Shadows are **projected, not shadow-mapped**. The key light direction is a
constant, so anything above the board can be flattened onto it: each part
drops two stacked quads (tight and dark, wide and faint, round for round
parts) and each wire drops a copy of its own curve. The tones are opaque
and picked against the board, so shadows never pile up into a dark blot and
never dither — a shadow map turns a 0.55-unit wire ribbon into noise, while
its projected curve is clean, cheap and subtle by construction. The board
drops the same kind of shadow onto the table.

The view is an orbit cam on a leash. Dragging the empty board circles the
setup, the wheel zooms, `F` frames the selected part and `0` reframes the
whole setup — which is also what happens when a preset is applied, so each
scenario arrives properly framed. Two rules keep you oriented: the camera
always looks at the setup (there is no free-flying pivot), and it must stay
at least 9 units above the board plane, so flattening the angle backs the
rig off instead of letting it dive through the parts. The compass under the
palette shows the board turning against a fixed marker for you, and the
table under the board gives a horizon at low angles.

Agents attach via `.clay/inspect/` (`Lab.labInfo()` reports the element
counts, net count, iteration count and short flag; probes `iBattery`,
`iLed` and `power` are plotted live and CSV-recordable). The entire
circuit — elements, wires, positions, rotations, switch states — plus the
camera pose rides in the dojo `viewState`, so the board you built and the
angle you were watching from both survive a QML reload untouched; a user's
board even wins over a scenario preset on reload.

## Source map

- Lab scene, palette, wiring and interaction: `labs/electronics-101/Sandbox.qml:1`
- DC nodal solver (`solve`): `labs/kits/circuit/circuit.js:107`
- Nets via union-find (`buildNets`): `labs/kits/circuit/circuit.js:41`
- Gaussian elimination (`solveLinear`): `labs/kits/circuit/circuit.js:68`
- Element conductances / Norton stamps: `labs/kits/circuit/circuit.js:92`, `labs/kits/circuit/circuit.js:135`
- LED piecewise model and flip-lock iteration: `labs/kits/circuit/circuit.js:124`, `labs/kits/circuit/circuit.js:146`
- Part visuals (LED glow, bulb glow): `labs/kits/circuit/CircuitElement3D.qml:1`, `labs/kits/circuit/CircuitElement3D.qml:136`, `labs/kits/circuit/CircuitElement3D.qml:171`
- Scenarios: `labs/electronics-101/Sandbox.qml:196`
- Probes: `labs/electronics-101/Sandbox.qml:26`
- viewState circuit persistence: `labs/electronics-101/Sandbox.qml:184`

*Verified via the clay-crew inspector on the running lab: the readings
above are read straight from the probes and meter pills; the solver's
19-case node suite covers the same circuits headless.*
