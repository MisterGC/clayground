// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the circuit kit's solver.
//
//     node labs/kits/circuit/circuit.test.js
//
// circuit.js is Qt-free (`.pragma library`) precisely so it can be checked
// here, with no running engine. What it covers is what is expensive to get
// wrong: the numbers the lab teaches (they are quoted in paper.md and by the
// flow's expect predicates), the short-vs-overload distinction, the LED's
// piecewise-linear fixed point, and the KCL peeling that attributes a current
// to each wire.
const K = require('../kitcheck.js')

const C = K.load(__dirname, 'circuit.js', ['solve', 'buildNets', 'terminalCount'])

// --- builders ---------------------------------------------------------------
// Same shapes the lab passes in: elements {id, type, value, on},
// wires {id, a: [elementId, terminal], b: [...]}.
let _id = 0
function board() {
    _id = 0
    return { els: [], wires: [] }
}
function el(b, type, value, on) {
    const e = { id: ++_id, type: type, value: value, on: !!on }
    b.els.push(e)
    return e.id
}
function wire(b, a, ta, c, tc) {
    b.wires.push({ id: ++_id, a: [a, ta], b: [c, tc] })
    return b.wires[b.wires.length - 1].id
}
function run(b) { return C.solve(b.els, b.wires) }

// A closed loop: out of the cell's + terminal (0), through each part from
// its terminal 0 to its terminal 1, back into the cell's - terminal (1).
// The direction matters - terminal 0 of an LED is its ANODE, so a loop wired
// the other way round is a reversed LED, not a lit one.
function loop(b, bat, parts) {
    let prev = bat, prevT = 0
    for (const p of parts) { wire(b, prev, prevT, p, 0); prev = p; prevT = 1 }
    wire(b, prev, prevT, bat, 1)
}

// ------------------------------------------------------------------ nets
K.section('nets')
{
    const b = board()
    const r1 = el(b, 'resistor', 470)
    const r2 = el(b, 'resistor', 470)
    K.eq('unwired terminals are their own nets', C.buildNets(b.els, b.wires).count, 4)
    wire(b, r1, 1, r2, 0)
    K.eq('a wire merges two terminals', C.buildNets(b.els, b.wires).count, 3)
    wire(b, r1, 1, r2, 0)
    K.eq('a redundant wire merges nothing new',
         C.buildNets(b.els, b.wires).count, 3)
}
{
    const b = board()
    const s = run(board())
    K.ok('an empty board solves', s.ok)
    K.eq('and has no nets', s.netCount, 0)
}

// ------------------------------------------------------- Ohm's law, series
K.section('the numbers the lab teaches')
{
    // 4.5 V cell (RINT 0.5) and one 470 ohm resistor
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [r])
    const s = run(b)
    K.near('one resistor: I = EMF / (RINT + R)',
           s.perElement[r].i, 4.5 / 470.5, 1e-6)
    K.near('the resistor drops nearly all of it',
           Math.abs(s.perElement[r].v), 4.5 * 470 / 470.5, 1e-6)
}
{
    // two in series: same current everywhere, the volts divide
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const r1 = el(b, 'resistor', 470)
    const r2 = el(b, 'resistor', 470)
    loop(b, bat, [r1, r2])
    const s = run(b)
    K.near('series: I = EMF / (RINT + R1 + R2)',
           s.perElement[r1].i, 4.5 / 940.5, 1e-6)
    K.near('series: the same current in both parts',
           s.perElement[r1].i, s.perElement[r2].i, 1e-9)
    K.near('series: the volts divide equally',
           Math.abs(s.perElement[r1].v), Math.abs(s.perElement[r2].v), 1e-9)
}
{
    // the LED circuit the flow builds, and the number it asserts: 5.15 mA
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const sw = el(b, 'switch', 0, true)
    const led = el(b, 'led', 0)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [sw, led, r])
    const s = run(b)
    K.near('the LED circuit draws 5.15 mA', s.perElement[led].i, 0.00515, 5e-5)
    K.ok('and the LED is lit', s.perElement[led].on)
    K.near('the LED sits near its forward voltage',
           s.perElement[led].v, 2.0 + 0.00515 * 15, 2e-3)
}
{
    // parallel: one voltage, the current splits
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const b1 = el(b, 'bulb', 0)
    const b2 = el(b, 'bulb', 0)
    wire(b, bat, 1, b1, 0); wire(b, bat, 1, b2, 0)
    wire(b, b1, 1, bat, 0); wire(b, b2, 1, bat, 0)
    const s = run(b)
    K.near('parallel: two 6 ohm bulbs across 4.5 V draw 4.5/3.5 A',
           Math.abs(s.batteries[bat].i), 4.5 / 3.5, 1e-6)
    K.near('parallel: the branches carry the same current',
           s.perElement[b1].i, s.perElement[b2].i, 1e-9)
    K.near('parallel: each branch takes half the total',
           Math.abs(s.perElement[b1].i), Math.abs(s.batteries[bat].i) / 2, 1e-6)
    K.ok('both bulbs light', s.perElement[b1].on && s.perElement[b2].on)
}

// ------------------------------------------------------------- switch, LED
K.section('switch and LED behaviour')
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const sw = el(b, 'switch', 0, false)
    const led = el(b, 'led', 0)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [sw, led, r])
    const s = run(b)
    K.ok('an open switch stops the current',
         Math.abs(s.perElement[led].i) < 1e-6)
    K.ok('and the LED stays dark', !s.perElement[led].on)
    // the flip-count lock: leak dividers behind an open switch can fake a
    // forward voltage, and an LED that keeps flip-flopping is pinned off
    K.ok('the solver still converges', s.iterations <= 12)
}
{
    // polarity: terminal 0 is the anode, so a reversed LED blocks
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const led = el(b, 'led', 0)
    const r = el(b, 'resistor', 470)
    wire(b, bat, 0, led, 1)      // cell + into the CATHODE
    wire(b, led, 0, r, 0)
    wire(b, r, 1, bat, 1)
    const s = run(b)
    K.ok('a reversed LED does not conduct', !s.perElement[led].on)
    K.ok('and passes no meaningful current',
         Math.abs(s.perElement[led].i) < 1e-6)
}
{
    // below the forward voltage nothing happens - the LED is not a resistor
    const b = board()
    const bat = el(b, 'battery', 1.5)
    const led = el(b, 'led', 0)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [led, r])
    const s = run(b)
    K.ok('1.5 V is under the forward voltage: dark', !s.perElement[led].on)
}

// ------------------------------------------------------ short vs overload
K.section('short is not the same as overload')
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    wire(b, bat, 0, bat, 1)               // a wire straight across the cell
    const s = run(b)
    K.near('a dead short draws EMF / RINT = 9 A',
           Math.abs(s.batteries[bat].i), 9.0, 1e-3)
    K.ok('and is reported as a short', s.shorted)
    K.ok('not as an overload', !s.overloaded)
    K.ok('almost nothing reaches the terminals', s.batteries[bat].vTerm < 0.1)
}
{
    // three bulbs in parallel: 1.8 A, an honest heavy load
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const ids = [el(b, 'bulb', 0), el(b, 'bulb', 0), el(b, 'bulb', 0)]
    for (const id of ids) { wire(b, bat, 1, id, 0); wire(b, id, 1, bat, 0) }
    const s = run(b)
    K.near('three bulbs draw 4.5 / 2.5 A', Math.abs(s.batteries[bat].i), 1.8, 1e-6)
    K.ok('that is an overload', s.overloaded)
    K.ok('but NOT a short', !s.shorted)
    K.ok('the terminal voltage survives', s.batteries[bat].vTerm > 3.0)
}
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [r])
    const s = run(b)
    K.ok('a normal load is neither', !s.shorted && !s.overloaded)
    K.ok('EMF splits into what reaches the parts and what is lost inside',
         Math.abs(s.batteries[bat].vTerm + s.batteries[bat].internalDrop
                  - s.batteries[bat].emf) < 1e-6)
}

// ------------------------------------------------------------ wire currents
K.section('per-wire current (KCL peeling)')
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const r1 = el(b, 'resistor', 470)
    const r2 = el(b, 'resistor', 470)
    const w = []
    w.push(wire(b, bat, 1, r1, 0))
    w.push(wire(b, r1, 1, r2, 0))
    w.push(wire(b, r2, 1, bat, 0))
    const s = run(b)
    const i = Math.abs(s.perElement[r1].i)
    K.ok('every wire in a series loop is resolved',
         w.every(id => s.wireCurrent[id] !== null))
    for (const id of w)
        K.near('and carries the loop current', Math.abs(s.wireCurrent[id]), i, 1e-6)
}
{
    // a junction splits a trunk into two branches: KCL must add up
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const j1 = el(b, 'junction', 0)
    const j2 = el(b, 'junction', 0)
    const b1 = el(b, 'bulb', 0)
    const b2 = el(b, 'bulb', 0)
    const trunk = wire(b, bat, 1, j1, 0)
    const br1 = wire(b, j1, 0, b1, 0)
    const br2 = wire(b, j1, 0, b2, 0)
    wire(b, b1, 1, j2, 0); wire(b, b2, 1, j2, 0)
    wire(b, j2, 0, bat, 0)
    const s = run(b)
    K.ok('the trunk is resolved', s.wireCurrent[trunk] !== null)
    if (s.wireCurrent[trunk] !== null && s.wireCurrent[br1] !== null
        && s.wireCurrent[br2] !== null) {
        K.near('the trunk carries the sum of its branches',
               Math.abs(s.wireCurrent[trunk]),
               Math.abs(s.wireCurrent[br1]) + Math.abs(s.wireCurrent[br2]), 1e-6)
    } else {
        K.ok('the branches are resolved', false, 'a branch stayed null')
    }
}
{
    // two wires in parallel between the same pair of terminals are genuinely
    // ambiguous - honest nulls beat invented numbers
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const r = el(b, 'resistor', 470)
    wire(b, bat, 1, r, 0)
    const dup1 = wire(b, r, 1, bat, 0)
    const dup2 = wire(b, r, 1, bat, 0)
    const s = run(b)
    K.ok('a redundant pair stays unattributed',
         s.wireCurrent[dup1] === null && s.wireCurrent[dup2] === null)
}

// ------------------------------------------------------------------ meters
K.section('meters')
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const amp = el(b, 'ammeter', 0)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [amp, r])
    const s = run(b)
    K.near('an ammeter reads the loop current and barely disturbs it',
           Math.abs(s.perElement[amp].i), 4.5 / 470.51, 1e-6)
}
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const r = el(b, 'resistor', 470)
    const volt = el(b, 'voltmeter', 0)
    loop(b, bat, [r])
    wire(b, volt, 0, r, 0); wire(b, volt, 1, r, 1)
    const s = run(b)
    K.near('a voltmeter reads the drop across the part it spans',
           Math.abs(s.perElement[volt].v), Math.abs(s.perElement[r].v), 1e-4)
    K.ok('while drawing almost no current',
         Math.abs(s.perElement[volt].i) < 1e-5)
}

// ------------------------------------------------------------------- diodes
K.section('the plain diode')
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const d = el(b, 'diode', 0)
    const r = el(b, 'resistor', 470)
    loop(b, bat, [d, r])
    const s = run(b)
    // the knee plus what its own 10 Ohm slope adds at this current - a
    // piecewise-linear diode is a knee AND a slope, never a fixed 0.7 V
    K.near('a forward diode drops its knee plus its slope',
           s.perElement[d].v, 0.7 + s.perElement[d].i * 10, 1e-9)
    K.near('and the resistor gets the rest',
           s.perElement[r].i, (4.5 - 0.7) / (470 + 10 + 0.5), 2e-5)
    K.ok('it conducts', s.perElement[d].on)
}
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    const d = el(b, 'diode', 0)
    const r = el(b, 'resistor', 470)
    // the same ring the other way round: cathode towards the cell's plus
    wire(b, bat, 0, d, 1); wire(b, d, 0, r, 0); wire(b, r, 1, bat, 1)
    const s = run(b)
    K.ok('reversed, it blocks', Math.abs(s.perElement[r].i) < 1e-6)
    K.ok('and reports itself off', !s.perElement[d].on)
}

// -------------------------------------------------------------- transistors
//
// The bench every logic scenario in the lab is built on: one cell, a plus rail
// (its terminal 0) and a ground rail (terminal 1). An input is a switch from
// the plus rail to a node with a 10 kOhm pull-down, so an open switch is a
// real 0 V and not a floating wire.
K.section('the transistor')

function bench(volts) {
    const b = board()
    const bat = el(b, 'battery', volts === undefined ? 4.5 : volts)
    return { b: b, bat: bat }
}
function input(bn, closed) {
    const sw = el(bn.b, 'switch', 0, closed)
    const pd = el(bn.b, 'resistor', 10000)
    wire(bn.b, bn.bat, 0, sw, 0)
    wire(bn.b, sw, 1, pd, 0)
    wire(bn.b, pd, 1, bn.bat, 1)
    return sw                        // the input node is the switch's terminal 1
}
// base resistor from an input node onto a transistor's base
function drive(bn, from, fromT, q, ohms) {
    const rb = el(bn.b, 'resistor', ohms === undefined ? 4700 : ohms)
    wire(bn.b, from, fromT, rb, 0)
    wire(bn.b, rb, 1, q, 1)
    return rb
}
// LED + series resistor hanging off the plus rail, ending at a free node
function ledBranch(bn) {
    const led = el(bn.b, 'led', 0)
    const rl = el(bn.b, 'resistor', 220)
    wire(bn.b, bn.bat, 0, led, 0)
    wire(bn.b, led, 1, rl, 0)
    return { led: led, tail: rl, tailT: 1 }
}

{
    const bn = bench()
    const sw = input(bn, false)
    const q = el(bn.b, 'transistor', 0)
    const br = ledBranch(bn)
    drive(bn, sw, 1, q)
    wire(bn.b, br.tail, br.tailT, q, 0)
    wire(bn.b, q, 2, bn.bat, 1)
    const s = run(bn.b)
    K.eq('an unpowered base leaves it cut off', s.perElement[q].mode, 'off')
    K.ok('and the LED stays dark', !s.perElement[br.led].on)
    K.ok('with no collector current', Math.abs(s.perElement[q].ic) < 1e-6)
}
{
    const bn = bench()
    const sw = input(bn, true)
    const q = el(bn.b, 'transistor', 0)
    const br = ledBranch(bn)
    drive(bn, sw, 1, q)
    wire(bn.b, br.tail, br.tailT, q, 0)
    wire(bn.b, q, 2, bn.bat, 1)
    const s = run(bn.b)
    const e = s.perElement[q]
    K.eq('4.5 V through 4.7 kOhm drives it into saturation', e.mode, 'sat')
    K.ok('the LED lights', s.perElement[br.led].on)
    K.near('the base takes about 0.8 mA', e.ib, (4.5 - 0.7) / (4700 + 25), 3e-5)
    K.ok('while the collector carries roughly ten times more',
         e.ic / e.ib > 8, 'ratio ' + (e.ic / e.ib))
    K.ok('a saturated transistor is nearly a closed switch', e.vce < 0.3,
         'vce ' + e.vce)
}
{
    // A base reached only through an OPEN switch. Cut-off leakage has to be
    // decades below an open contact's, or the two form a divider that puts
    // half the supply on the base and a disconnected input switches the
    // transistor on - which is what this board caught.
    const bn = bench()
    const sw = el(bn.b, 'switch', 0, false)
    const q = el(bn.b, 'transistor', 0)
    const rb = el(bn.b, 'resistor', 4700)
    const br = ledBranch(bn)
    wire(bn.b, bn.bat, 0, sw, 0)
    wire(bn.b, sw, 1, rb, 0)
    wire(bn.b, rb, 1, q, 1)
    wire(bn.b, br.tail, br.tailT, q, 0)
    wire(bn.b, q, 2, bn.bat, 1)
    const s = run(bn.b)
    K.eq('a base behind an open switch stays cut off', s.perElement[q].mode, 'off')
    K.ok('and the base sits far below its knee', s.perElement[q].vbe < 0.1,
         'vbe ' + s.perElement[q].vbe)
    K.ok('so the LED stays dark', !s.perElement[br.led].on)
}
{
    // Starved base: 470 kOhm lets through so little that BETA * Ib is below
    // what the collector branch wants, so the part sits in its ACTIVE region
    // and the current gain is on show rather than hidden by saturation.
    const bn = bench()
    const sw = input(bn, true)
    const q = el(bn.b, 'transistor', 0)
    const br = ledBranch(bn)
    drive(bn, sw, 1, q, 470000)
    wire(bn.b, br.tail, br.tailT, q, 0)
    wire(bn.b, q, 2, bn.bat, 1)
    const s = run(bn.b)
    const e = s.perElement[q]
    K.eq('a starved base leaves it in the active region', e.mode, 'active')
    // BETA exactly, plus the 100 kOhm collector-emitter leak that stands in
    // for the Early effect - which is why this is 103 and not 100
    K.near('and the collector carries BETA times the base current',
           (e.ic - e.vce / 1e5) / e.ib, 100, 1e-6)
}

// ------------------------------------------------------------------- gates
//
// The three gates the lab ships, as truth tables. Every row is a solve: the
// answer is the LED's own `on`, exactly what a learner reads off the board.
K.section('logic gates')

// AND: the two transistors are in SERIES, so the current has to pass through
// both of them - the same picture as the lab's series-circuit preset.
function andGate(a, b2) {
    const bn = bench()
    const sa = input(bn, a), sb = input(bn, b2)
    const q1 = el(bn.b, 'transistor', 0)
    const q2 = el(bn.b, 'transistor', 0)
    const br = ledBranch(bn)
    drive(bn, sa, 1, q1)
    drive(bn, sb, 1, q2)
    wire(bn.b, br.tail, br.tailT, q1, 0)
    wire(bn.b, q1, 2, q2, 0)
    wire(bn.b, q2, 2, bn.bat, 1)
    const s = run(bn.b)
    return { on: s.perElement[br.led].on, s: s, led: br.led }
}
K.ok('AND 0 0 -> dark', !andGate(false, false).on)
K.ok('AND 1 0 -> dark', !andGate(true, false).on)
K.ok('AND 0 1 -> dark', !andGate(false, true).on)
K.ok('AND 1 1 -> lit',   andGate(true, true).on)
K.ok('and the lit LED runs at a sane current',
     andGate(true, true).s.perElement[andGate(true, true).led].i > 0.004)

// OR: the two transistors are in PARALLEL, so either one on is enough - the
// lab's parallel-circuit preset, in silicon.
function orGate(a, b2) {
    const bn = bench()
    const sa = input(bn, a), sb = input(bn, b2)
    const q1 = el(bn.b, 'transistor', 0)
    const q2 = el(bn.b, 'transistor', 0)
    const br = ledBranch(bn)
    drive(bn, sa, 1, q1)
    drive(bn, sb, 1, q2)
    wire(bn.b, br.tail, br.tailT, q1, 0)
    wire(bn.b, br.tail, br.tailT, q2, 0)
    wire(bn.b, q1, 2, bn.bat, 1)
    wire(bn.b, q2, 2, bn.bat, 1)
    const s = run(bn.b)
    return { on: s.perElement[br.led].on, s: s, led: br.led }
}
K.ok('OR 0 0 -> dark', !orGate(false, false).on)
K.ok('OR 1 0 -> lit',   orGate(true, false).on)
K.ok('OR 0 1 -> lit',   orGate(false, true).on)
K.ok('OR 1 1 -> lit',   orGate(true, true).on)

// Diode OR: no transistors at all. Two DRIVEN inputs - each a switch with a
// pull-down, so an open one is a real 0 V - and a diode from each into the
// lamp, so neither input can drive the other.
function diodeOr(a, b2) {
    const bn = bench()
    const sa = input(bn, a), sb = input(bn, b2)
    const dA = el(bn.b, 'diode', 0)
    const dB = el(bn.b, 'diode', 0)
    const led = el(bn.b, 'led', 0)
    const r = el(bn.b, 'resistor', 220)
    wire(bn.b, sa, 1, dA, 0); wire(bn.b, dA, 1, led, 0)
    wire(bn.b, sb, 1, dB, 0); wire(bn.b, dB, 1, led, 0)
    wire(bn.b, led, 1, r, 0); wire(bn.b, r, 1, bn.bat, 1)
    const s = run(bn.b)
    return { on: s.perElement[led].on, s: s, dA: dA, dB: dB, led: led }
}
K.ok('diode OR 0 0 -> dark', !diodeOr(false, false).on)
K.ok('diode OR 1 0 -> lit',   diodeOr(true, false).on)
K.ok('diode OR 0 1 -> lit',   diodeOr(false, true).on)
K.ok('diode OR 1 1 -> lit',   diodeOr(true, true).on)
{
    // Regression: a diode feeding a load that is ITSELF still assumed off
    // carries almost nothing on that pass. Read as "stopped", it switched off,
    // the LED lost its supply and followed, and the pair oscillated until both
    // were pinned - a gate that solved to dark with the supply connected. A
    // conducting diode stays on until its current reverses, not until it is
    // merely small.
    const g = diodeOr(true, false)
    K.ok('one input alone lights it', g.on)
    K.ok('and it converges quickly', g.s.iterations <= 6,
         'iterations ' + g.s.iterations)
    K.ok('the fed branch carries the lamp current',
         Math.abs(g.s.perElement[g.dA].i - g.s.perElement[g.led].i) < 1e-7,
         'diff ' + (g.s.perElement[g.dA].i - g.s.perElement[g.led].i))
    K.ok('and the idle branch carries nothing',
         Math.abs(g.s.perElement[g.dB].i) < 1e-9)
    K.ok('because it is reverse biased, not merely quiet',
         g.s.perElement[g.dB].v < -1, 'v ' + g.s.perElement[g.dB].v)
}

// XOR, built from the two gates above plus the NAND they are hiding.
//
//   Q1 in series with Q2 is a NAND: its collector is pulled up to the rail
//   unless BOTH inputs are high. That node drives Q5, which sits under the
//   OR pair (Q3 parallel Q4) - so the LED needs (A or B) AND not (A and B).
function xorGate(a, b2) {
    const bn = bench()
    const sa = input(bn, a), sb = input(bn, b2)
    const q1 = el(bn.b, 'transistor', 0)   // NAND, upper
    const q2 = el(bn.b, 'transistor', 0)   // NAND, lower
    const q3 = el(bn.b, 'transistor', 0)   // OR, A
    const q4 = el(bn.b, 'transistor', 0)   // OR, B
    const q5 = el(bn.b, 'transistor', 0)   // the inhibit, driven by the NAND
    const rn = el(bn.b, 'resistor', 4700)  // NAND pull-up
    const br = ledBranch(bn)
    drive(bn, sa, 1, q1); drive(bn, sb, 1, q2)
    drive(bn, sa, 1, q3); drive(bn, sb, 1, q4)
    wire(bn.b, bn.bat, 0, rn, 0); wire(bn.b, rn, 1, q1, 0)
    wire(bn.b, q1, 2, q2, 0)
    wire(bn.b, q2, 2, bn.bat, 1)
    drive(bn, q1, 0, q5)                   // NAND output onto Q5's base
    wire(bn.b, br.tail, br.tailT, q3, 0)
    wire(bn.b, br.tail, br.tailT, q4, 0)
    wire(bn.b, q3, 2, q5, 0)
    wire(bn.b, q4, 2, q5, 0)
    wire(bn.b, q5, 2, bn.bat, 1)
    const s = run(bn.b)
    return { on: s.perElement[br.led].on, s: s, q5: q5, q1: q1, led: br.led }
}
K.ok('XOR 0 0 -> dark', !xorGate(false, false).on)
K.ok('XOR 1 0 -> lit',   xorGate(true, false).on)
K.ok('XOR 0 1 -> lit',   xorGate(false, true).on)
K.ok('XOR 1 1 -> dark', !xorGate(true, true).on)
{
    const both = xorGate(true, true)
    K.eq('with both inputs high the inhibit transistor is cut off',
         both.s.perElement[both.q5].mode, 'off')
    K.ok('because the NAND node has collapsed to nearly nothing',
         both.s.perElement[both.q1].vce + 0 < 1,
         'vce ' + both.s.perElement[both.q1].vce)
    const one = xorGate(true, false)
    K.eq('with one input high it is saturated instead',
         one.s.perElement[one.q5].mode, 'sat')
}

// -------------------------------------------------- gates as whole packages
//
// The behavioural gate is a PACKAGE, not a discrete part: five pins, two of
// them the supply it runs on, and an output that can only swing between what
// those two pins carry. It is driven from the same bench the transistor
// sections use, so a "1" on an input is a real 4.5 V arriving through a
// switch, and a "0" is a real 0 V held by a pull-down.
K.section('logic gates (as packages)')

// The builder above only knows {type, value, on}; a gate also carries which
// function it is.
function gate(b, func) {
    const e = { id: ++_id, type: 'gate', func: func }
    b.els.push(e)
    return e.id
}
// a gate hung on the bench rails: VCC (terminal 0) on plus, GND (4) on ground
function powered(bn, func) {
    const g = gate(bn.b, func)
    wire(bn.b, bn.bat, 0, g, 0)
    wire(bn.b, bn.bat, 1, g, 4)
    return g
}
// one row of a truth table: two driven inputs onto A (1) and B (2)
function gateRow(func, a, b2) {
    const bn = bench()
    const g = powered(bn, func)
    const sa = input(bn, a), sb = input(bn, b2)
    wire(bn.b, sa, 1, g, 1)
    wire(bn.b, sb, 1, g, 2)
    return { g: g, s: run(bn.b) }
}
const ROWS = [[false, false], [false, true], [true, false], [true, true]]
const bit = row => (row[0] ? '1' : '0') + ' ' + (row[1] ? '1' : '0')

{
    K.eq('a gate has five terminals', C.terminalCount('gate'), 5)
    K.eq('while a resistor still has two', C.terminalCount('resistor'), 2)
    const b = board()
    const g = gate(b, 'and')
    K.eq('an unwired gate is five nets', C.buildNets(b.els, b.wires).count, 5)
    wire(b, g, 0, g, 4)                  // its own supply pins shorted together
    K.eq('and a wire between two of its pins merges them',
         C.buildNets(b.els, b.wires).count, 4)
}
{
    // No VCC pin wired. The package has nothing to swing between, so it drives
    // nothing at all - which is the point of giving it supply pins: a gate
    // that invented its own rail would answer here, and it should not.
    const bn = bench()
    const g = gate(bn.b, 'or')
    wire(bn.b, bn.bat, 1, g, 4)          // ground only
    const sa = input(bn, true)
    wire(bn.b, sa, 1, g, 1)
    const rl = el(bn.b, 'resistor', 220)
    const led = el(bn.b, 'led', 0)
    wire(bn.b, g, 3, rl, 0)
    wire(bn.b, rl, 1, led, 0)
    wire(bn.b, led, 1, bn.bat, 1)
    const s = run(bn.b)
    const e = s.perElement[g]
    K.ok('an unwired supply leaves the gate unpowered', !e.powered)
    K.near('and it says the supply it saw was nothing', e.vcc, 0, 1e-3)
    K.ok('well under the volt it needs to work', e.vcc < 0.5, 'vcc ' + e.vcc)
    K.ok('a high input cannot make it answer', !e.on && !e.y)
    K.ok('its output pin is high impedance', Math.abs(e.i) < 1e-6, 'i ' + e.i)
    K.ok('so nothing downstream lights', !s.perElement[led].on)
    K.ok('and every number is still finite',
         isFinite(e.v) && isFinite(e.i) && isFinite(e.power) && isFinite(e.vcc))
}

// The six functions, every row a solve. NOT is on the same table on purpose:
// its B pin is wired and driven, and it still has to be ignored.
const TRUTH = {
    and:  [false, false, false, true],
    or:   [false, true,  true,  true],
    xor:  [false, true,  true,  false],
    nand: [true,  true,  true,  false],
    nor:  [true,  false, false, false],
    not:  [true,  true,  false, false]
}
for (const func in TRUTH) {
    for (let row = 0; row < 4; ++row) {
        const r = gateRow(func, ROWS[row][0], ROWS[row][1])
        K.eq(func.toUpperCase() + ' ' + bit(ROWS[row]),
             r.s.perElement[r.g].on, TRUTH[func][row])
    }
}
{
    const loRow = gateRow('and', true, false)
    const e = loRow.s.perElement[loRow.g]
    K.ok('a powered gate says so', e.powered)
    K.near('and reports the supply it actually saw', e.vcc, 4.5, 0.05)
    K.ok('it read A high and B low', e.a && !e.b)
    K.eq('and it knows which function it is', e.func, 'and')
    K.ok('a low output sits at the GND pin', Math.abs(e.v) < 0.01, 'v ' + e.v)
    const hiRow = gateRow('or', true, false)
    const hiE = hiRow.s.perElement[hiRow.g]
    K.ok('an unloaded high output sits at the VCC pin',
         hiE.vcc - hiE.v < 0.01, 'v ' + hiE.v + ' vcc ' + hiE.vcc)
}
{
    // The output is push-pull through 50 ohm onto the PADS, so a load gets
    // what that resistance and the supply allow, never a clean rail.
    const bn = bench()
    const g = powered(bn, 'or')
    const sa = input(bn, true), sb = input(bn, false)
    wire(bn.b, sa, 1, g, 1)
    wire(bn.b, sb, 1, g, 2)
    const rl = el(bn.b, 'resistor', 220)
    const led = el(bn.b, 'led', 0)
    wire(bn.b, g, 3, rl, 0)
    wire(bn.b, rl, 1, led, 0)
    wire(bn.b, led, 1, bn.bat, 1)
    const s = run(bn.b)
    const e = s.perElement[g]
    K.ok('a driven output lights an LED', s.perElement[led].on)
    K.near('the LED gets what the output pin offers it',
           s.perElement[led].i, (e.v - 2.0) / (220 + 15), 1e-9)
    // to within the nanoamp GLEAK takes off the output node, which is numerics
    // and not a part of the circuit
    K.near('and the gate sources that same current', e.i, s.perElement[led].i, 1e-8)
    K.near('the output sags by 50 ohm times what it delivers',
           e.vcc - e.v, 50 * e.i, 1e-9)
    K.near('which lands the branch near 8.8 mA', s.perElement[led].i, 0.0088, 3e-4)
}
for (const row of ROWS) {
    // The whole point of the part: one gate's output is the next one's input,
    // and the second answers the composition. OR into NOT is a NOR.
    const bn = bench()
    const g1 = powered(bn, 'or')
    const g2 = powered(bn, 'not')
    const sa = input(bn, row[0]), sb = input(bn, row[1])
    wire(bn.b, sa, 1, g1, 1)
    wire(bn.b, sb, 1, g1, 2)
    wire(bn.b, g1, 3, g2, 1)
    const s = run(bn.b)
    K.eq('OR into NOT is a NOR: ' + bit(row),
         s.perElement[g2].on, !(row[0] || row[1]))
    K.eq('and the second gate read the first one as its A input',
         s.perElement[g2].a, s.perElement[g1].on)
    K.ok('the chain settles', s.iterations <= 8, 'iterations ' + s.iterations)
}
for (const row of ROWS) {
    // A half adder: two gates on the SAME pair of inputs, sum = A xor B and
    // carry = A and B, both read off their own output pins.
    const bn = bench()
    const sum = powered(bn, 'xor')
    const carry = powered(bn, 'and')
    const sa = input(bn, row[0]), sb = input(bn, row[1])
    wire(bn.b, sa, 1, sum, 1)
    wire(bn.b, sb, 1, sum, 2)
    wire(bn.b, sa, 1, carry, 1)
    wire(bn.b, sb, 1, carry, 2)
    const s = run(bn.b)
    K.eq('half adder sum ' + bit(row), s.perElement[sum].on, row[0] !== row[1])
    K.eq('half adder carry ' + bit(row), s.perElement[carry].on, row[0] && row[1])
}
{
    // A real chip draws current doing nothing, and here that is measurable
    // rather than a rounding error: R_GATE_Q straight across the supply.
    const bn = bench()
    const g = powered(bn, 'and')
    const s = run(bn.b)
    const e = s.perElement[g]
    K.near('an idle gate draws its quiescent current',
           Math.abs(s.batteries[bn.bat].i), 4.5 / (1e5 + 0.5), 1e-7)
    K.ok('which is small but not nothing',
         Math.abs(s.batteries[bn.bat].i) > 1e-6)
    K.ok('and it dissipates that much', e.power > 1e-5, 'power ' + e.power)
    K.ok('its unwired inputs read low, not undefined', !e.a && !e.b)
    K.ok('so an AND with nothing on it answers low', !e.on)
    K.ok('the cell notices no load worth the name', !s.overloaded && !s.shorted)
}
{
    // Five pads cannot be signed by a rule, so the solver publishes what each
    // one sends into the wires. They have to add up to nothing.
    const bn = bench()
    const g = powered(bn, 'nand')
    const sa = input(bn, true), sb = input(bn, true)
    wire(bn.b, sa, 1, g, 1)
    wire(bn.b, sb, 1, g, 2)
    const rl = el(bn.b, 'resistor', 470)   // pull-up: a low output has to sink
    wire(bn.b, bn.bat, 0, rl, 0)
    const load = wire(bn.b, rl, 1, g, 3)
    const s = run(bn.b)
    const e = s.perElement[g]
    K.eq('the solver publishes one current per pad', e.term.length, 5)
    let sum = 0
    for (const t of e.term) sum += t
    K.ok('and the five of them sum to zero', Math.abs(sum) < 1e-9, 'sum ' + sum)
    K.eq('the output pad is the current the entry reports', e.term[3], e.i)
    K.ok('a low output sinks instead of sourcing', e.term[3] < -1e-3,
         'i ' + e.term[3])
    K.ok('the supply pad feeds the package', e.term[0] < 0, 'i ' + e.term[0])
    K.ok('and the ground pad returns everything', e.term[4] > 0, 'i ' + e.term[4])
    K.near('the load wire carries what the output pad said',
           Math.abs(s.wireCurrent[load]), Math.abs(e.i), 1e-8)
}
{
    // determinism, same as for the rest of the solver: paper.md and the flow
    // quote these numbers, so two identical boards may not differ at all
    const build = () => {
        const bn = bench()
        const g = powered(bn, 'xor')
        const sa = input(bn, true), sb = input(bn, false)
        wire(bn.b, sa, 1, g, 1)
        wire(bn.b, sb, 1, g, 2)
        const rl = el(bn.b, 'resistor', 220)
        wire(bn.b, g, 3, rl, 0)
        wire(bn.b, rl, 1, bn.bat, 1)
        return bn.b
    }
    K.eq('the same gate board solves to the same numbers',
         JSON.stringify(run(build()).perElement),
         JSON.stringify(run(build()).perElement))
}

// ---------------------------------------------------------------- robustness
K.section('robustness')
{
    const b = board()
    const bat = el(b, 'battery', 4.5)
    el(b, 'resistor', 470)                 // an island: wired to nothing
    const r2 = el(b, 'resistor', 470)
    loop(b, bat, [r2])
    const s = run(b)
    K.ok('a disconnected island still solves', s.ok)
    let finite = true
    for (const id in s.perElement) {
        const e = s.perElement[id]
        if (!isFinite(e.v) || !isFinite(e.i) || !isFinite(e.power)) finite = false
    }
    K.ok('and every number stays finite', finite)
}
{
    // determinism: the same board must always give the same answer, because
    // paper.md quotes these numbers and the flow asserts them
    const build = () => {
        const b = board()
        const bat = el(b, 'battery', 4.5)
        const sw = el(b, 'switch', 0, true)
        const led = el(b, 'led', 0)
        const r = el(b, 'resistor', 470)
        loop(b, bat, [sw, led, r])
        return b
    }
    const a = JSON.stringify(run(build()).perElement)
    const c = JSON.stringify(run(build()).perElement)
    K.eq('the same board solves to the same numbers', a, c)
}


// --- the board contract (parts.js) ---------------------------------------------
const Parts = K.load(__dirname, 'parts.js', ['spec', 'catalog', 'DEFAULT_VOLTS'])
K.section('board spec')
K.ok('every catalog type has a spec', Parts.catalog.every(c => Parts.spec[c.type] !== undefined))
K.ok('the junction has two coincident pads at the origin, as the solver models it',
     Parts.spec.junction.terminals.length === 2 && Parts.spec.junction.terminals.every(t => t.x === 0 && t.y === 0))
K.ok('two pads in a line is the rule', ['battery', 'switch', 'resistor', 'led', 'bulb', 'diode', 'ammeter', 'voltmeter']
     .every(t => Parts.spec[t].terminals.length === 2 && Parts.spec[t].terminals[0].x === -3.5))
K.ok('the transistor has three pads, the base off axis', Parts.spec.transistor.terminals.length === 3 && Parts.spec.transistor.terminals[1].y === 3.5)
K.ok('the gate is a five-pin package', Parts.spec.gate.terminals.length === 5 && Parts.spec.gate.half.x === 7.0)
K.ok('only the switch has an actuator', Object.keys(Parts.spec).every(t => (Parts.spec[t].actuator !== null) === (t === 'switch')))
K.ok('every part carries value, on and func', Object.keys(Parts.spec).every(t => {
    const f = Parts.spec[t].fields
    return 'value' in f && 'on' in f && 'func' in f && f.on === false
}))
K.ok('defaults: 470 ohm, 4.5 V, a gate answers AND', Parts.spec.resistor.fields.value === 470
     && Parts.spec.battery.fields.value === Parts.DEFAULT_VOLTS && Parts.spec.gate.fields.func === 'and')
K.ok('card rows: state / func / value', Parts.spec.switch.rows[0] === 'state' && Parts.spec.gate.rows[0] === 'func'
     && Parts.spec.resistor.rows[0] === 'value' && Parts.spec.battery.rows[0] === 'value' && Parts.spec.led.rows.length === 0)
K.ok('the junction takes no plot', Parts.spec.junction.watch === false)

process.exit(K.report('circuit kit'))
