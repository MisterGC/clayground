# Electronics 101 — a school kit that obeys Kirchhoff

*Companion paper to the interactive lab in `labs/electronics-101/`.
Overview board: `overview.grafli`. Study: `studies/series-vs-parallel/`.
Annotate freely with CriticMarkup — remarks feed the next lab iteration.*

## The question

Every school electronics set makes the same promise: snap a battery, a
switch and a lamp together and the lamp lights. What the plastic parts
never show is *why* — why two bulbs in series glow dim while the same two
in parallel blaze, why a resistor tames an LED, why one careless wire
from plus to minus is a short. This lab puts the kit on a 3D pegboard and
runs a real circuit solver underneath it: you take parts out of the
palette, wire terminals by clicking two gold pads, flip the switch,
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

## Short circuit vs. heavy load

These are different faults and the lab used to conflate them: any battery
current above 1.5 A raised a *SHORT CIRCUIT* banner. Two 6 Ω bulbs in
parallel are 3 Ω, so the same, perfectly sound wiring was silent at 4.5 V
(1.29 A) and accused of a short at 5.5 V (1.57 A). The threshold was
measuring the wrong quantity.

A short is not "a lot of current" — it is the **external resistance
collapsing to the order of the cell's own**. The solver now computes what
the cell actually sees,

$$
R_\mathrm{ext} = \frac{V_\mathrm{term}}{|I|},
\qquad V_\mathrm{term} = \mathrm{EMF} - |I|\,R_\mathrm{int}
$$

and calls it a short when $R_\mathrm{ext} < 2R_\mathrm{int}$. Two parallel
bulbs sit at $R_\mathrm{ext} = 3.01\,\Omega$ at *every* voltage — never a
short, however hard you push them; past the cell's 1.5 A rating they are
merely an **overload**, which now says so in its own words and colour.

The explanation is visual, and the widget is reusable: selecting a battery
shows a **`BudgetBar`** (in `Clayground.Lab`) splitting the EMF into what
reaches your parts and what is lost inside the cell. On a healthy circuit
the bar is almost all teal. On an overload a clay sliver appears — the cell
is starting to eat its own voltage. On a real short the bar goes **entirely
red**: every volt is burned internally, nothing is left for the parts, which
is precisely why they go dark. Wires past the rating are drawn in alarm
colour on the board and in the schematic, so the bypass path is visible as
the thing carrying everything. A `BudgetBar` answers "where does it all go?"
for any conserved quantity — volts round a loop, current at a junction,
power in a machine — so other labs can borrow it as-is.

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
- **Ideal cells.** A battery's voltage is whatever you set on it (each cell
  has its own, so a board can mix a 1.5 V and a 9 V one); only its internal
  resistance limits current. Real cells sag and run down — these do not.

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

## The same contrast, run as a study

The two rows above are one voltage of a question that deserves a sweep, so
the lab carries one: **`studies/series-vs-parallel/`** asks what the wiring
decides across the cell's whole usable range, 1.5 V to 12 V, twelve runs
driven headlessly by `tools/lab-sweep` and committed as twelve run records.
The study document states the question, argues its own answerability against
this kit's model card, and only then reports; everything below is quoted from
`studies/series-vs-parallel/results.md`, which is generated from the records
rather than typed.

Three findings, and the third is the one this table could not have shown:

1. **Parallel delivers 3.18× the power, at every voltage.** Not approximately
   — the same figure at all six levels, because both wirings are linear in
   the cell's EMF. Turning the cell up cannot turn a series board into a
   parallel one; the choice of wiring is a property of the circuit.
2. **It asks for 3.564× the current to do it.** The two ratios differ, and
   the gap is what the cell keeps for itself: a series board gets **96 %** of
   the cell's volts to its bulbs, a parallel board **86 %**. The honest form
   of "parallel is brighter" is *parallel asks for 3.56× as much and gets
   3.18× as much back, because a cell takes a bigger cut when you lean on it.*
3. **Only one of them ever reaches the cell's rating.** Computed from each
   record's own $R_\mathrm{ext} = V_\mathrm{term}/|I|$, the parallel board
   crosses 1.5 A at **5.27 V** and is over it from 6 V up; the series board
   would need **18.8 V**, which is past the cell's ceiling. Neither is ever a
   short — 3.01 Ω is still six times the cell's own 0.5 Ω, however hard it is
   pushed, which is the distinction argued above being checked rather than
   asserted.

`R_ext` is 12.01 Ω in series and 3.01 Ω in parallel, read off the records as
$V_\mathrm{term}/|I|$ — the two bulbs stacked against the two bulbs halved.
Every other number in the study follows from those two by Ohm's law, which is
why none of the ratios move with voltage.

## Things to try

- **Push the LED to its ceiling.** Set the resistor to 100 Ω and drag the
  battery's own slider up to 12 V. The current climbs but the LED clamps near its
  $V_F$ knee — most of the extra volts now burn in the resistor, not the
  diode. Put the LED and the resistor on the plot, switch it to *voltage*,
  and watch the LED's curve flatten while the resistor's climbs.
- **Read series and parallel off one plot.** Both presets seed the monitor
  with the cell and one bulb. In `series` the two current curves lie on top
  of each other (one current everywhere) while *voltage* shows the cell's
  volts shared out; in `parallel` the currents separate exactly 2:1 while
  the voltages coincide. Same two curves, opposite lessons.
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
- **Clip a meter on and keep what it says.** Press `H` until the voltmeter
  (`⚡`) is in your hand, click a bulb, and it reads that bulb live while you
  keep working. Press `P`, give the reading a name, and it becomes a probe
  like any other — on the plot, in the recording, and in a run record a paper
  can cite. It is the shortest path in the lab from *I wonder* to *a number
  somebody else can check*.

## Run it

```bash
./build/bin/claydojo --sbx labs/electronics-101/Sandbox.qml
```

Keys: `1` led-basic · `2` series · `3` parallel · `4` metering ·
`T` the guided flow · `E` eraser · `C` clear · `V` value labels ·
`M` the schematic · `#` grid mode · `R` turn the selected part ·
`Q` put it on the plot · `Del` remove it · `F` frame it · `0` reset the
view · `H` the next instrument · `P` keep a reading · `Esc` cancel ·
`Shift+R` record a run. `EN`/`DE` in the top right switch the language.

Take a part from the palette by clicking it: a semi-transparent **ghost** of
that part then follows the cursor at the cell it would snap to, a click puts
it there, and `Esc` or a right-click puts it back down. The ghost is drawn
in the refusal colour where the cell is already taken, so a placement that
will not work says so before the click rather than after it. Click two gold
terminals to wire, click a switch to flip it, click a resistor to cycle its
ohms, drag a part to move it, and click a wire anywhere along its length to
branch off it (the eraser removes wires, junctions and parts alike). Every
preset starts with the switch **open** — flipping it is the invitation.

Parts try to say what they are without a legend. The palette shows each
part's **schematic symbol** (IEC 60617) next to its colour, because the
palette is the one place a kit can teach *this lump is that squiggle* for
free. On the board, several parts are **printed with Qt Quick items rendered
to textures**: a battery carries its polarity and its voltage on a paper
label, a switch prints `ON`/`OFF` (a tilted lever is hard to read from
straight above), and each meter has a real dial — scale, needle, and an
auto-selected range, so an ammeter reading 5 mA switches itself to a 10 mA
scale and says so. A resistor needs no print: its bands are the actual
colour code, two significant digits plus a decade, so they change with the
value the way a bought resistor's do.

Values are set where the part is, not in a global panel. Selecting a
resistor puts a slider on its card that walks the **E12 series** — the
values a shop actually sells — and selecting a battery gives it its own
volts, so a board can hold a 1.5 V cell next to a 9 V one. There is
deliberately no global voltage parameter any more: one slider per cell is
both simpler to explain and strictly more capable.

`M` toggles the **Schaltplan**: a live schematic of the board in the corner,
drawn with the same symbols the palette shows — parts where the parts are,
lines where the wires are, energised wires in ink and idle ones faint. It
fits itself to what you built. The 3D board shows what you assembled; the
schematic shows what it *is*, and watching both at once is how the diagram
in a textbook stops being an abstraction.

Wires meet at **junctions**: click any wire and a solder dot is dropped
where you clicked, splitting it in two and starting a branch from that point
— which is what makes a real parallel circuit buildable instead of a star of
wires from one terminal. A junction is electrically neutral (a short between
its two coincident terminals), so inserting one never changes a reading. The
`parallel` preset is built from them and is laid out as a ladder — two rungs
between two rails, source at the bottom — because a parallel circuit that
looks like a tangle teaches the wrong thing.

The lab speaks **English or German**, switched by the `EN`/`DE` chips in the
top right corner while it runs. Translation is a runtime dictionary
(`LabLang` in `Clayground.Lab`), not `qsTr`: retranslating a live QML engine
is a C++ call on the engine, which a lab hosted by the dojo — or exported to
the web — never owns. Every string is therefore an ordinary binding that
re-evaluates when the language changes, including the text printed *onto*
the parts, so a switch reads `EIN`/`AUS` in German. Numbers switch with the
words: German shows `4,32 V` and `641,0 mA`, in the plot's axis and legend
too, because that is how a student writes it in their exercise book. The
kit owns the part vocabulary (`labs/kits/circuit/strings.js`), the lab its
own copy (`labs/electronics-101/strings.js`), and a lab may override a kit's
wording by registering later. Key letters are physical and never translated:
`Q`, `V`, `R` and `#` are the same on a German keyboard.

The **monitor** in the corner plots the board, not a fixed pair of curves.
Select a part and press `Q` (or hit *plot it* on its card) and it gets a
probe, a colour and a curve; the same colour appears as a small tag on the
part, so *which line is which* is read off the board instead of inferred
from the legend order. Clicking a legend entry drops that curve again, and
deleting a part takes its curve with it. Presets seed a watch list that
suits what they are about, and an empty board says so instead of showing
leftovers.

One quantity is plotted at a time — *current*, *voltage* or *power*, by the
chips above the plot. That is partly honesty (all series share one
autoscaled axis, so mixing mA with V would flatten the volts onto the
baseline) and partly the lesson: the same two parts tell you about series
wiring under *voltage* and about parallel wiring under *current*. Switching
quantity clears the curves, because the axis is no longer the same axis.

`V` toggles **value labels**: every part shows its current and voltage and
every wire its current. That one toggle is the lab's whole argument, made
readable: in series the same current appears on every wire while the
voltages divide; in parallel the same voltage sits across both rungs while
the current splits and re-joins at the junctions.

Hovering a part draws a thin blue outline around it on the paper, the same
blue the terminals light up in; clicking **selects** it, which thickens that
outline, adds a nose mark showing which way the part faces, and opens a card
reporting its voltage and current. `R` turns it in 90° steps — wires
follow the terminals. (The right button belongs to the camera in every lab:
a right drag turns the view, a right click puts down whatever is in hand.) Moving is grid-snapped by default, exactly like
grafli's grid mode: the pegs are drawn as small squares while snapping and
as round dots when parts move freely, `#` cycles the mode and holding `Alt`
inverts it for one drag. The peg raster is 5 world units — half a part
width — so snapped parts can still be nudged in fine steps; `cellFree`
therefore keeps two pegs of clearance around every part.

Shadows are **real** — a GPU shadow map on the key light, so they follow
whatever you move. Two things make them legible at this scale:

- **A small shadow volume.** `shadowMapFar` bounds the map to the board and
  the table instead of the horizon (a table the size of the horizon starves
  the map), and two cascades spend their texels near the camera. The far
  plane still has to cover the setup at full zoom-out, since the range is
  measured from the camera, not from the light.
- **A small bias.** `shadowBias` at 3 works; at 10 and up thin shadows are
  pushed off the board entirely and at 0 the whole board turns to acne. It
  was worth measuring rather than eyeballing — the failure at both ends
  looks identical from a distance ("no shadows").

Wires lie **flat on the board** and are drawn as one instanced line batch
(`LineBatch3D` in `Flat` orientation), which is what buys the current
animation: each wire is an ink line with a chevron pattern marching along it,
speed bucketed by current magnitude, pointing the way the current actually
runs. No current, no chevrons — so an open switch or a backwards LED is
visible at a glance instead of only in the numbers. Parts are sunk slightly
into the board and their terminals are near-flush pads, so the wires meet
them at board level. Nobody expects a shadow from a line lying on paper, so
shadows are now a question only for the parts, where they work.

Giving each wire a direction needs a little care. A wire cannot be oriented
by voltage: in this model a wire **is** the net (ideal, zero resistance), so
both of its ends sit at exactly the same potential by construction. What is
known is every element's current, so `attributeWireCurrents` derives the
wires from Kirchhoff's current law: repeatedly find a terminal where only one
wire's current is still unknown, and that wire's current follows from the
others. Tree-shaped wiring resolves completely; a genuinely ambiguous wire
(two wires in parallel between the same two terminals) stays unknown and
simply does not animate, which is the honest answer.

The view is an orbit cam on a leash, and it never takes the left button (see
*The left button is the lab's* below). A right drag circles the setup, a
middle drag slides it, the wheel zooms at the cursor, `WASD` and the arrows
pan, `Shift` with the arrows turns, `F` frames the selected part and `0`
reframes the whole setup — which is also what happens when a preset is
applied, so each scenario arrives properly framed. Holding `Space` lends the
left button to panning for exactly as long as it is held, for anyone who
would rather drag than press a key. Two rules keep you oriented: the camera
always looks at the setup (there is no free-flying pivot), and it must stay
at least 9 units above the board plane, so flattening the angle backs the
rig off instead of letting it dive through the parts. The compass under the
palette shows the board turning against a fixed marker for you, and the
table under the board gives a horizon at low angles.

Agents attach via `.clay/inspect/` (`Lab.labInfo()` reports the element
counts, net count, iteration count and the short and overload flags, plus
which parts are being watched and in which quantity). Three probes are
setup-independent and always registered — `iBattery`, the total supply
current, `power`, the total dissipated in the loads, and `vTerm`, what the
cells actually hand to the parts after their own internal drop — so a
recording has stable columns whatever the board looks like. Every watched part adds a `part<id>` probe
next to them, which is also the agent-facing way to plot something:
`setWatched(id, true)`. The entire
circuit — elements, wires, positions, rotations, switch states — plus the
camera pose rides in the dojo `viewState`, so the board you built and the
angle you were watching from both survive a QML reload untouched; a user's
board even wins over a scenario preset on reload.

## Instruments you hold

An instrument in a lab used to be one of two things: bolted into the scene,
or parked in a corner of the screen. Both are **mounted** — the author
decides what they measure, and the learner only reads them. A tape measure
is neither. What it measures is whatever you point it at, and pointing is
the whole instrument.

So there is a third way to hold one, and it is the ordinary one: the strip
along the bottom edge of the screen is a **belt**, `H` walks along it, and
whatever is in your hand takes the next left click. Three instruments ride
there in every lab, undeclared:

- **the tape measure** (`📏`) — two clicks are two places, and the reading is
  the distance between them. Here it answers *how far apart are those pads*
  without touching the board.
- **the stopwatch** (`⏱`) — clicks are moments on the simulated clock, not
  places, so it needs no aim at all. The same contract, with the pointing
  removed.
- **the voltmeter** (`⚡`) — a click names a **part**, and the meter stays
  clipped to it, reading live. This one is the circuit kit's, not the
  kernel's: it is a handheld instrument a kit ships, which is the point of
  having a written contract for them.

A reading you want to keep is kept with `P`, which asks what to call it and
then registers it as an ordinary **probe** — so a measurement somebody took
by hand joins the plot, the recording and the run record, under the name they
gave it. That is the whole path from a click to a citable number, and it is
why `pin` exists rather than a screenshot.

And the palette is on the same belt, which is the part worth noticing:
**taking a part to place is taking an instrument.** A build tool is just an
instrument whose reading is an act — it takes a place and, instead of
remembering it, puts something there. That is what lets building and
navigating happen without switching between them.

### The left button is the lab's

One rule holds all of that up: **the camera never takes the left button.**
Orbiting is a right drag, sliding is a middle drag, zooming is the wheel,
and everything else is on the keyboard. The left button belongs to whatever
the lab is doing — flipping a switch, wiring two pads, placing a part,
measuring between two pads — and no camera state can take it away.

The test the design is held to is stated as a failure: *if a lab's tool can
be starved of the left button by any camera state, the design is wrong.* It
had been wrong. Placing parts used to be a mode, and while you were in it the
switch on the board could not be flipped, because the camera had the press.
Removing the mode removed the bug; the ghost that now previews a placement is
what the mode had been standing in for.

`Space` is the one exception, and it is a quasimode rather than a mode: it
lends the left button to panning for exactly as long as it is held down.

## Source map

- Lab scene, palette, wiring and interaction: `labs/electronics-101/Sandbox.qml:1`
- DC nodal solver (`solve`): `labs/kits/circuit/circuit.js:107`
- Nets via union-find (`buildNets`): `labs/kits/circuit/circuit.js:41`
- Gaussian elimination (`solveLinear`): `labs/kits/circuit/circuit.js:68`
- Element conductances / Norton stamps: `labs/kits/circuit/circuit.js:92`, `labs/kits/circuit/circuit.js:135`
- LED piecewise model and flip-lock iteration: `labs/kits/circuit/circuit.js:124`, `labs/kits/circuit/circuit.js:146`
- Part visuals (LED glow, bulb glow): `labs/kits/circuit/CircuitElement3D.qml:1`, `labs/kits/circuit/CircuitElement3D.qml:136`, `labs/kits/circuit/CircuitElement3D.qml:171`
- Scenarios (each seeds its own watch list): `labs/electronics-101/Sandbox.qml:444`
- Fixed probes (`iBattery`, `power`, `vTerm`): `labs/electronics-101/Sandbox.qml:50`
- Watch list and the monitor: `labs/electronics-101/Sandbox.qml:100`, `labs/electronics-101/Sandbox.qml:1828`
- Board tags: `labs/electronics-101/Sandbox.qml:1572`
- The belt, and the palette as a tool on it: `labs/electronics-101/Sandbox.qml:721`, `labs/electronics-101/Sandbox.qml:731`
- The placement ghost: `labs/electronics-101/Sandbox.qml:796`
- The guided flow (`led-basics`): `labs/electronics-101/Sandbox.qml:1266`
- Handheld contract and belt (kernel): `plugins/clay_lab/HandheldInstrument.qml:1`, `plugins/clay_lab/InstrumentBelt.qml:1`
- Tape measure, stopwatch (kernel): `plugins/clay_lab/TapeMeasure.qml:1`, `plugins/clay_lab/Stopwatch.qml:1`
- The kit's handheld voltmeter: `labs/kits/circuit/Voltmeter.qml:1`
- The camera that never takes the left button (kernel): `plugins/clay_canvas3d/OrbitInput3D.qml:1`
- Runtime-driven plot series (kernel): `plugins/clay_lab/Plot2D.qml:50`
- Language switch (kernel): `plugins/clay_lab/LabLang.qml:1`, `plugins/clay_lab/LangSwitch.qml:1`
- Dictionaries: `labs/electronics-101/strings.js:1`, `labs/kits/circuit/strings.js:1`
- viewState circuit persistence: `labs/electronics-101/Sandbox.qml:412`
- The study, its records and its figures: `labs/electronics-101/studies/series-vs-parallel/study.md`

*Verified via the clay-crew inspector on the running lab: the readings
above are read straight from the probes and meter pills; the solver's
19-case node suite covers the same circuits headless.*
