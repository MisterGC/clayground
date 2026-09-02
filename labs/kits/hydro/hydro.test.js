// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the hydro kit's solver and board contract.
//
//     node labs/kits/hydro/hydro.test.js
//
// hydro.js and parts.js are Qt-free (`.pragma library`) precisely so they can
// be checked here, with no running engine. What it covers is what is expensive
// to get wrong: the numbers a lab would teach (they end up quoted in a paper
// and asserted by a flow), the short-versus-overload distinction that is the
// whole point of an internal resistance, the continuity peeling that gives
// each pipe run a flow, and the board contract a Board store reads.
const K = require('../kitcheck.js')

const H = K.load(__dirname, 'hydro.js',
                 ['solve', 'buildNets', 'pipeSteps', 'pipeStepOf',
                  'resistanceOf', 'P0_DEFAULT', 'RINT', 'RCLOSED', 'ROPEN',
                  'RWHEEL', 'RMETER', 'RGAUGE', 'Q_RATED', 'P_TURN',
                  'RPM_PER_FLOW'])
const P = K.load(__dirname, 'parts.js',
                 ['spec', 'catalog', 'specOf', 'terminalCount', 'defaults',
                  'padAt', 'colorOf'])
const S = K.load(__dirname, 'strings.js', ['dict'])

// --- builders ---------------------------------------------------------------
// Same shapes a lab passes in: elements {id, type, value, on},
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
function pipe(b, a, ta, c, tc) {
    b.wires.push({ id: ++_id, a: [a, ta], b: [c, tc] })
    return b.wires[b.wires.length - 1].id
}
function run(b) { return H.solve(b.els, b.wires) }

// A closed circuit: out of the pump's OUTLET (terminal 0), through each part
// from its terminal 0 to its terminal 1, back into the pump's suction side.
function loop(b, pump, parts) {
    let prev = pump, prevT = 0
    for (const p of parts) { pipe(b, prev, prevT, p, 0); prev = p; prevT = 1 }
    pipe(b, prev, prevT, pump, 1)
}

// ------------------------------------------------------------------ nets
K.section('nets')
{
    const b = board()
    const p1 = el(b, 'pipe', 8)
    const p2 = el(b, 'pipe', 8)
    K.eq('unconnected terminals are their own nets',
         H.buildNets(b.els, b.wires).count, 4)
    pipe(b, p1, 1, p2, 0)
    K.eq('a pipe run merges two terminals', H.buildNets(b.els, b.wires).count, 3)
    pipe(b, p1, 1, p2, 0)
    K.eq('a redundant run merges nothing new',
         H.buildNets(b.els, b.wires).count, 3)
}
{
    const s = run(board())
    K.ok('an empty board solves', s.ok)
    K.eq('and has no nets', s.netCount, 0)
    K.eq('and no pipe flows', Object.keys(s.wireFlow).length, 0)
}

// ------------------------------------------------------- the analogy itself
K.section('the numbers the lab teaches')
{
    // pump (40 kPa, RINT 2) -> open valve -> pipe 8 -> water wheel
    const b = board()
    const pu = el(b, 'pump', 40)
    const v = el(b, 'valve', 0, true)
    const pi = el(b, 'pipe', 8)
    const wh = el(b, 'wheel', 0)
    loop(b, pu, [v, pi, wh])
    const s = run(b)
    const rTot = H.RINT + H.RCLOSED + 8 + H.RWHEEL
    K.near('one loop: Q = P0 / (RINT + Rvalve + Rpipe + RWHEEL)',
           s.perElement[pi].q, 40 / rTot, 1e-6)
    K.near('the same flow passes every part in the loop',
           s.perElement[wh].q, s.perElement[pi].q, 1e-6)
    K.near('the narrow pipe eats dp = R * Q',
           Math.abs(s.perElement[pi].dp), 8 * 40 / rTot, 1e-6)
    K.near('the wheel eats dp = RWHEEL * Q',
           Math.abs(s.perElement[wh].dp), H.RWHEEL * 40 / rTot, 1e-6)
    K.near('power on the wheel is dp * Q, in watts with no conversion',
           s.perElement[wh].power, H.RWHEEL * Math.pow(40 / rTot, 2), 1e-6)
    K.ok('the wheel turns', s.perElement[wh].on)
    K.near('and its speed is proportional to flow',
           s.perElement[wh].speed, (40 / rTot) * H.RPM_PER_FLOW, 1e-6)
    K.ok('a plain pipe never claims to turn', !s.perElement[pi].on)
}
{
    // two narrow pipes in series: same flow, the pressure drops divide
    const b = board()
    const pu = el(b, 'pump', 40)
    const p1 = el(b, 'pipe', 8)
    const p2 = el(b, 'pipe', 8)
    loop(b, pu, [p1, p2])
    const s = run(b)
    K.near('series: Q = P0 / (RINT + R1 + R2)',
           s.perElement[p1].q, 40 / 18, 1e-6)
    K.near('series: the same flow in both', s.perElement[p1].q,
           s.perElement[p2].q, 1e-9)
    K.near('series: the pressure divides equally',
           Math.abs(s.perElement[p1].dp), Math.abs(s.perElement[p2].dp), 1e-9)
}
{
    // parallel: one pressure across both, the flow splits
    const b = board()
    const pu = el(b, 'pump', 40)
    const w1 = el(b, 'wheel', 0)
    const w2 = el(b, 'wheel', 0)
    pipe(b, pu, 0, w1, 0); pipe(b, pu, 0, w2, 0)
    pipe(b, w1, 1, pu, 1); pipe(b, w2, 1, pu, 1)
    const s = run(b)
    K.near('parallel: two 24 kPa*s/L wheels are a 12 load',
           Math.abs(s.pumps[pu].q), 40 / (H.RINT + 12), 1e-6)
    K.near('parallel: the branches carry the same flow',
           s.perElement[w1].q, s.perElement[w2].q, 1e-9)
    K.near('parallel: each branch takes half the delivery',
           Math.abs(s.perElement[w1].q), Math.abs(s.pumps[pu].q) / 2, 1e-6)
    K.ok('both wheels turn', s.perElement[w1].on && s.perElement[w2].on)
}
{
    // the lesson the internal resistance exists for: a second wheel in
    // parallel moves more water AND pulls the outlet pressure down, while in
    // series it does neither
    const one = board()
    const pu1 = el(one, 'pump', 40)
    loop(one, pu1, [el(one, 'wheel', 0)])
    const s1 = run(one)

    const par = board()
    const pu2 = el(par, 'pump', 40)
    const a = el(par, 'wheel', 0), c = el(par, 'wheel', 0)
    pipe(par, pu2, 0, a, 0); pipe(par, pu2, 0, c, 0)
    pipe(par, a, 1, pu2, 1); pipe(par, c, 1, pu2, 1)
    const s2 = run(par)

    const ser = board()
    const pu3 = el(ser, 'pump', 40)
    loop(ser, pu3, [el(ser, 'wheel', 0), el(ser, 'wheel', 0)])
    const s3 = run(ser)

    K.ok('parallel draws more than one wheel alone',
         Math.abs(s2.pumps[pu2].q) > Math.abs(s1.pumps[pu1].q))
    K.ok('series draws less than one wheel alone',
         Math.abs(s3.pumps[pu3].q) < Math.abs(s1.pumps[pu1].q))
    K.ok('and the parallel load makes the outlet pressure sag',
         s2.pumps[pu2].pTerm < s1.pumps[pu1].pTerm)
    K.ok('while the series load lets it recover',
         s3.pumps[pu3].pTerm > s1.pumps[pu1].pTerm)
    K.near('parallel: P0 splits into what reaches the wheels and what is lost'
           + ' inside the pump',
           s2.pumps[pu2].pTerm + s2.pumps[pu2].internalDrop,
           s2.pumps[pu2].p0, 1e-6)
}

// ------------------------------------------------------------------- valve
K.section('the valve')
{
    const b = board()
    const pu = el(b, 'pump', 40)
    const v = el(b, 'valve', 0, false)
    const wh = el(b, 'wheel', 0)
    loop(b, pu, [v, wh])
    const s = run(b)
    K.ok('a closed valve stops the flow', Math.abs(s.perElement[wh].q) < 1e-6)
    K.ok('so the wheel stands still', !s.perElement[wh].on)
    K.eq('and reports no speed', s.perElement[wh].speed < 1e-4, true)
    K.ok('the valve reports its own state', !s.perElement[v].on)
    K.ok('the pump is then neither shorted nor overloaded',
         !s.shorted && !s.overloaded)
}
{
    const b = board()
    const pu = el(b, 'pump', 40)
    const v = el(b, 'valve', 0, true)
    const wh = el(b, 'wheel', 0)
    loop(b, pu, [v, wh])
    const s = run(b)
    K.ok('an open valve lets it run', s.perElement[wh].on)
    K.ok('and says so', s.perElement[v].on)
    K.near('an open valve is nearly free',
           Math.abs(s.perElement[v].dp),
           H.RCLOSED * Math.abs(s.perElement[wh].q), 1e-6)
}
{
    // a wheel behind a very narrow pipe: flowing, but not working
    const b = board()
    const pu = el(b, 'pump', 40)
    const wh = el(b, 'wheel', 0)
    loop(b, pu, [el(b, 'pipe', 1000), wh])
    const s = run(b)
    K.ok('a trickle turns nothing', !s.perElement[wh].on)
    K.ok('though water does move', Math.abs(s.perElement[wh].q) > 1e-3)
    K.ok('the wheel only turns above P_TURN', s.perElement[wh].power < H.P_TURN)
}

// ------------------------------------------------------- short vs overload
K.section('a short is not an overload')
{
    const b = board()
    const pu = el(b, 'pump', 40)
    pipe(b, pu, 0, pu, 1)               // outlet piped straight back to suction
    const s = run(b)
    K.near('a dead short delivers P0 / RINT = 20 L/s',
           Math.abs(s.pumps[pu].q), 20.0, 1e-3)
    K.ok('and is reported as a short', s.shorted)
    K.ok('not as an overload', !s.overloaded)
    K.ok('almost no pressure reaches the parts', s.pumps[pu].pTerm < 0.5)
}
{
    // three wheels in parallel: 4 L/s, an honest heavy load
    const b = board()
    const pu = el(b, 'pump', 40)
    const ids = [el(b, 'wheel', 0), el(b, 'wheel', 0), el(b, 'wheel', 0)]
    for (const id of ids) { pipe(b, pu, 0, id, 0); pipe(b, id, 1, pu, 1) }
    const s = run(b)
    K.near('three wheels draw 40 / 10 L/s', Math.abs(s.pumps[pu].q), 4.0, 1e-6)
    K.ok('that is an overload', s.overloaded)
    K.ok('but NOT a short', !s.shorted)
    K.ok('the outlet pressure survives', s.pumps[pu].pTerm > 30)
    K.ok('the flag is on the pump too', s.pumps[pu].overloaded)
}
{
    const b = board()
    const pu = el(b, 'pump', 40)
    loop(b, pu, [el(b, 'pipe', 8), el(b, 'wheel', 0)])
    const s = run(b)
    K.ok('a normal load is neither', !s.shorted && !s.overloaded)
    K.near('P0 = what reaches the parts + what is lost inside the pump',
           s.pumps[pu].pTerm + s.pumps[pu].internalDrop, s.pumps[pu].p0, 1e-6)
    K.ok('and it is working against a real external resistance',
         s.pumps[pu].rExt > 2 * H.RINT)
    K.eq('the rated flow is reported with it', s.pumps[pu].rated, H.Q_RATED)
}

// ---------------------------------------------------------------- per-pipe
K.section('per-pipe flow (continuity peeling)')
{
    const b = board()
    const pu = el(b, 'pump', 40)
    const p1 = el(b, 'pipe', 8)
    const p2 = el(b, 'pipe', 8)
    const runs = []
    runs.push(pipe(b, pu, 0, p1, 0))
    runs.push(pipe(b, p1, 1, p2, 0))
    runs.push(pipe(b, p2, 1, pu, 1))
    const s = run(b)
    const q = Math.abs(s.perElement[p1].q)
    K.ok('every run in a series loop is resolved',
         runs.every(id => s.wireFlow[id] !== null))
    for (const id of runs)
        K.near('and carries the loop flow', Math.abs(s.wireFlow[id]), q, 1e-6)
}
{
    // a T-piece splits a trunk into two branches: continuity must add up
    const b = board()
    const pu = el(b, 'pump', 40)
    const j1 = el(b, 'junction', 0)
    const j2 = el(b, 'junction', 0)
    const w1 = el(b, 'wheel', 0)
    const w2 = el(b, 'wheel', 0)
    const trunk = pipe(b, pu, 0, j1, 0)
    const br1 = pipe(b, j1, 0, w1, 0)
    const br2 = pipe(b, j1, 0, w2, 0)
    pipe(b, w1, 1, j2, 0); pipe(b, w2, 1, j2, 0)
    pipe(b, j2, 0, pu, 1)
    const s = run(b)
    K.ok('the trunk is resolved', s.wireFlow[trunk] !== null)
    K.ok('and so are both branches',
         s.wireFlow[br1] !== null && s.wireFlow[br2] !== null)
    if (s.wireFlow[trunk] !== null && s.wireFlow[br1] !== null
        && s.wireFlow[br2] !== null) {
        K.near('the trunk carries the sum of its branches',
               Math.abs(s.wireFlow[trunk]),
               Math.abs(s.wireFlow[br1]) + Math.abs(s.wireFlow[br2]), 1e-6)
        K.near('and each branch takes half of it',
               Math.abs(s.wireFlow[br1]),
               Math.abs(s.wireFlow[trunk]) / 2, 1e-6)
    }
    K.near('a T-piece costs nothing in series',
           Math.abs(s.pumps[pu].q), 40 / (H.RINT + H.RWHEEL / 2), 1e-4)
}
{
    // two runs in parallel between the same pair of pads are genuinely
    // ambiguous - honest nulls beat invented numbers
    const b = board()
    const pu = el(b, 'pump', 40)
    const pi = el(b, 'pipe', 8)
    pipe(b, pu, 0, pi, 0)
    const dup1 = pipe(b, pi, 1, pu, 1)
    const dup2 = pipe(b, pi, 1, pu, 1)
    const s = run(b)
    K.ok('a redundant pair stays unattributed',
         s.wireFlow[dup1] === null && s.wireFlow[dup2] === null)
}

// ------------------------------------------------------------------ meters
K.section('meters')
{
    const b = board()
    const pu = el(b, 'pump', 40)
    const fm = el(b, 'flowmeter', 0)
    const pi = el(b, 'pipe', 8)
    loop(b, pu, [fm, pi])
    const s = run(b)
    K.near('a flowmeter reads the loop flow and barely disturbs it',
           Math.abs(s.perElement[fm].q), 40 / (H.RINT + H.RMETER + 8), 1e-6)
    const clean = 40 / (H.RINT + 8)
    K.ok('the disturbance it causes stays under half a percent',
         Math.abs(Math.abs(s.perElement[fm].q) - clean) / clean < 5e-3)
}
{
    const b = board()
    const pu = el(b, 'pump', 40)
    const pi = el(b, 'pipe', 8)
    const g = el(b, 'gauge', 0)
    loop(b, pu, [pi])
    pipe(b, g, 0, pi, 0); pipe(b, g, 1, pi, 1)
    const s = run(b)
    K.near('a pressure gauge across a part reads its dp',
           Math.abs(s.perElement[g].dp), Math.abs(s.perElement[pi].dp), 1e-4)
    K.ok('while passing almost no water', Math.abs(s.perElement[g].q) < 1e-5)
}

// -------------------------------------------------------------- pipe ladder
K.section('the pipe ladder')
{
    K.ok('the ladder is not empty', H.pipeSteps.length > 10)
    let rising = true
    for (let i = 1; i < H.pipeSteps.length; ++i)
        if (!(H.pipeSteps[i] > H.pipeSteps[i - 1])) rising = false
    K.ok('and strictly increasing', rising)
    K.ok('the default 8 is a rung', H.pipeSteps.indexOf(8) >= 0)
    let trips = true
    for (const v of H.pipeSteps)
        if (H.pipeSteps[H.pipeStepOf(v)] !== v) trips = false
    K.ok('every rung round trips through pipeStepOf', trips)
    K.eq('the first rung is index 0', H.pipeStepOf(H.pipeSteps[0]), 0)
    K.eq('a value between rungs picks the nearer one in log space',
         H.pipeSteps[H.pipeStepOf(8.5)], 8)
    K.eq('which is not the same as the nearer one on a linear scale',
         H.pipeSteps[H.pipeStepOf(9)], 10)
    K.eq('and clamps below the ladder', H.pipeStepOf(0.0001), 0)
    K.eq('and above it', H.pipeStepOf(1e9), H.pipeSteps.length - 1)
}

// ---------------------------------------------------------- board contract
K.section('the board contract')
{
    let allSpecced = true
    for (const c of P.catalog) if (!P.spec[c.type]) allSpecced = false
    K.ok('every catalog entry has a spec', allSpecced)
    K.ok('the T-piece is not in the palette',
         !P.catalog.some(c => c.type === 'junction'))
    K.ok('but it has a spec', !!P.spec.junction)

    let twoTerm = true, padded = true
    for (const t of ['pump', 'valve', 'pipe', 'wheel', 'flowmeter', 'gauge']) {
        if (P.terminalCount(t) !== 2) twoTerm = false
        const ts = P.spec[t].terminals
        if (ts[0].x !== -3.5 || ts[1].x !== 3.5 || ts[0].y !== 0 || ts[1].y !== 0)
            padded = false
    }
    K.ok('every placeable part has two terminals', twoTerm)
    K.ok('and its pads sit at -/+3.5 on the raster', padded)
    K.eq('the T-piece has exactly one', P.terminalCount('junction'), 1)
    K.eq('at the part origin, x', P.spec.junction.terminals[0].x, 0)
    K.eq('and y', P.spec.junction.terminals[0].y, 0)

    K.eq('a two-terminal body is 4.6 half-wide', P.spec.pipe.half.x, 4.6)
    K.eq('and 3.4 half-deep', P.spec.pipe.half.y, 3.4)
    K.eq('a T-piece is a 2.3 square', P.spec.junction.half.x, 2.3)
    K.ok('the keep-out is left to the board, which derives it from the footprint',
         P.spec.pump.keepOut === undefined && P.spec.junction.keepOut === undefined)

    K.ok('the valve is the only part you operate', !!P.spec.valve.actuator)
    K.eq('its handwheel is 2.6 half-wide', P.spec.valve.actuator.x, 2.6)
    let others = true
    for (const t of ['pump', 'pipe', 'wheel', 'flowmeter', 'gauge', 'junction'])
        if (P.spec[t].actuator !== null) others = false
    K.ok('nothing else has an actuator', others)

    K.eq('a pump defaults to 40 kPa', P.spec.pump.fields.value, 40)
    K.eq('a pipe defaults to 8 kPa*s/L', P.spec.pipe.fields.value, 8)
    K.eq('a valve starts open', P.spec.valve.fields.on, true)
    K.eq('the pump offers a value row', P.spec.pump.rows[0], 'value')
    K.eq('the valve offers a state row', P.spec.valve.rows[0], 'state')
    K.eq('the wheel offers nothing to set', P.spec.wheel.rows.length, 0)
    K.eq('terminal 0 of a pump is its outlet', P.spec.pump.termNames[0], 'out')

    const d = P.defaults('pipe')
    d.value = 999
    K.eq('defaults() hands out a copy', P.spec.pipe.fields.value, 8)
    K.eq('with the domain fields in it', P.defaults('valve').on, true)
    K.eq('an unknown type has no spec', P.specOf('sprocket'), null)
    K.ok('every catalog entry carries a colour',
         P.catalog.every(c => /^#[0-9a-f]{6}$/i.test(c.color)))
    K.eq('colorOf agrees with the catalog', P.colorOf('pump'), P.catalog[0].color)
}
{
    // the rotation convention, written once in parts.js and asserted here
    const p0 = P.padAt('pipe', 0, 10, 20, 0)
    K.near('unrotated, pad 0 sits to the left', p0.x, 6.5, 1e-9)
    K.near('on the same row', p0.z, 20, 1e-9)
    const p90 = P.padAt('pipe', 0, 10, 20, 90)
    K.near('a quarter turn puts it downstream in z, x', p90.x, 10, 1e-9)
    K.near('and z', p90.z, 23.5, 1e-9)
    const p180 = P.padAt('pipe', 0, 10, 20, 180)
    K.near('half a turn swaps the pads', p180.x, 13.5, 1e-9)
    const j = P.padAt('junction', 0, 7, -3, 45)
    K.near('a T-piece pad never moves, x', j.x, 7, 1e-9)
    K.near('a T-piece pad never moves, z', j.z, -3, 1e-9)
}

// ------------------------------------------------------------- the vocabulary
K.section('the vocabulary')
{
    // A missing German key is invisible until a German lesson runs into it,
    // so the two dictionaries are checked against each other here instead.
    const en = Object.keys(S.dict.en).sort()
    const de = Object.keys(S.dict.de).sort()
    K.eq('EN and DE have the same number of keys', en.length, de.length)
    K.eq('and exactly the same keys', en.join('|'), de.join('|'))
    let empty = false
    for (const k of en)
        if (!S.dict.en[k] || !S.dict.de[k]) empty = true
    K.ok('nothing is left blank', !empty)

    let covered = true
    for (const t of Object.keys(P.spec)) {
        if (!S.dict.en['part.' + t]) covered = false
        if (!S.dict.en['part.' + t + '.hint']) covered = false
        if (!S.dict.en['code.' + t]) covered = false
    }
    K.ok('every part type has a name, a hint and a short code', covered)
    for (const k of ['quantity.flow', 'quantity.pressure', 'quantity.power',
                     'valve.open', 'valve.closed', 'valve.on', 'valve.off',
                     'pump.reaches', 'pump.lost', 'pump.ok', 'pump.heavy',
                     'pump.short', 'pump.open'])
        K.ok('the lab can say "' + k + '"', !!S.dict.en[k] && !!S.dict.de[k])
}

// ---------------------------------------------------------------- robustness
K.section('robustness')
{
    const b = board()
    const pu = el(b, 'pump', 40)
    el(b, 'pipe', 8)                       // an island: connected to nothing
    const p2 = el(b, 'pipe', 8)
    loop(b, pu, [p2])
    const s = run(b)
    K.ok('a disconnected island still solves', s.ok)
    let finite = true
    for (const id in s.perElement) {
        const e = s.perElement[id]
        if (!isFinite(e.q) || !isFinite(e.dp) || !isFinite(e.power)) finite = false
    }
    K.ok('and every number stays finite', finite)
    K.eq('a linear model needs exactly one pass', s.iterations, 1)
}
{
    const build = () => {
        const b = board()
        const pu = el(b, 'pump', 40)
        loop(b, pu, [el(b, 'valve', 0, true), el(b, 'pipe', 8),
                     el(b, 'wheel', 0)])
        return b
    }
    const a = JSON.stringify(run(build()).perElement)
    const c = JSON.stringify(run(build()).perElement)
    K.eq('the same board solves to the same numbers', a, c)
    K.eq('an unknown part type is treated as a blank plug',
         H.resistanceOf({ id: 1, type: 'sprocket' }), H.ROPEN)
}

process.exit(K.report('hydro kit'))
