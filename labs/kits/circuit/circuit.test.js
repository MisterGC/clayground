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

const C = K.load(__dirname, 'circuit.js', ['solve', 'buildNets'])

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

process.exit(K.report('circuit kit'))
