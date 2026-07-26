// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the traffic kit's pure modules.
//
//     node labs/kits/traffic/traffic.test.js
//
// The kit's logic is deliberately Qt-free (.pragma library, no Qt.vector3d)
// precisely so it can be checked here, in a second, without a running engine.
// The suite strips the pragma and evaluates each module into a scope.
//
// It covers the two things that are expensive to get wrong: the DERIVATION
// (graph -> lanes, junction boxes, turn fans, conflicts) and the SIM's
// invariants (determinism, no overlaps, one car per turn, no deadlock).
// The deadlock cases at the end are regressions - each of those (seed, demand)
// pairs once brought a network to a complete standstill.
const fs = require('fs')
const path = require('path')

const KIT = process.argv[2] || __dirname

function load(name, exports) {
    const src = fs.readFileSync(path.join(KIT, name), 'utf8')
        .replace(/^\s*\.pragma\s+library\s*$/m, '')
    const fn = new Function(src + '\nreturn {' + exports.join(',') + '}')
    return fn()
}

const G = load('roadgraph.js', ['empty', 'clone', 'addNode', 'insertRoad', 'removeRoad',
    'removeNode', 'nodeById', 'roadById', 'degree', 'incident', 'nearestNode',
    'nearestRoad', 'splitRoad', 'bounds', 'totalLength', 'setLanes', 'roadLength',
    'isBanned', 'setBanned', 'toggleBanned', 'pruneBans'])
const L = load('lanemodel.js', ['derive', 'poseOn', 'surfaceRuns', 'laneRuns',
    'markingRuns', 'LANE_W', 'elementLength'])
const T = load('traffic.js', ['createState', 'step', 'defaultParams', 'targetCount',
    'summary', 'meanSpeed', 'rehome', 'stoppedShare'])

let pass = 0, fail = 0
function ok(name, cond, extra) {
    if (cond) { pass++; console.log('  ok   ' + name) }
    else { fail++; console.log('  FAIL ' + name + (extra ? '  <- ' + extra : '')) }
}
function eq(name, got, want) { ok(name, got === want, 'got ' + got + ', want ' + want) }
function near(name, got, want, tol) {
    ok(name, Math.abs(got - want) <= tol, 'got ' + got + ', want ~' + want)
}
function section(s) { console.log('\n' + s) }

// deterministic rng for the sim tests (mulberry32, same as SimClock)
function rngFrom(seed) {
    let a = seed >>> 0
    return function () {
        a = (a + 0x6D2B79F5) | 0
        let t = a
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

// ---------------------------------------------------------------- roadgraph
section('roadgraph: building')
{
    const g = G.empty()
    const r = G.insertRoad(g, 0, 0, 60, 0, {})
    ok('a plain road is accepted', r.ok)
    eq('two nodes', g.nodes.length, 2)
    eq('one road', g.roads.length, 1)
    near('length', G.totalLength(g), 60, 1e-6)

    const tooShort = G.insertRoad(g, 100, 100, 103, 100, {})
    ok('a stub is refused', !tooShort.ok)
    eq('refusal names the reason', tooShort.reason, 'short')
}
{
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    // a second road ENDING on the first must split it into an intersection
    G.insertRoad(g, 30, -40, 30, 0, {})
    eq('T-junction: nodes', g.nodes.length, 4)
    eq('T-junction: roads', g.roads.length, 3)
    const mid = G.nearestNode(g, 30, 0, 1)
    ok('the T node exists', mid !== null)
    eq('the T node has degree 3', G.degree(g, mid.id), 3)
}
{
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    // crossing straight through must split BOTH roads
    G.insertRoad(g, 30, -30, 30, 30, {})
    eq('crossing: nodes', g.nodes.length, 5)
    eq('crossing: roads', g.roads.length, 4)
    const mid = G.nearestNode(g, 30, 0, 1)
    eq('the crossing has degree 4', G.degree(g, mid.id), 4)
}
{
    // one long road across three parallels: a chain of three intersections
    const g = G.empty()
    G.insertRoad(g, 0, 0, 0, 90, {})
    G.insertRoad(g, 40, 0, 40, 90, {})
    G.insertRoad(g, 80, 0, 80, 90, {})
    G.insertRoad(g, -20, 45, 100, 45, {})
    eq('comb: nodes', g.nodes.length, 6 + 3 + 2)
    eq('comb: roads', g.roads.length, 6 + 4)
    for (const x of [0, 40, 80]) {
        const n = G.nearestNode(g, x, 45, 1)
        ok('crossing at x=' + x + ' is a 4-way', n !== null && G.degree(g, n.id) === 4)
    }
}
{
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    G.insertRoad(g, 60, 0, 60, 60, {})   // endpoint lands exactly on a node
    eq('shared endpoint does not duplicate a node', g.nodes.length, 3)
    eq('shared endpoint: roads', g.roads.length, 2)
    const corner = G.nearestNode(g, 60, 0, 1)
    eq('the corner has degree 2', G.degree(g, corner.id), 2)
}
{
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    G.insertRoad(g, 30, -30, 30, 30, {})
    const before = g.roads.length
    G.removeRoad(g, g.roads[0].id)
    eq('removing a road removes it', g.roads.length, before - 1)
    ok('orphan nodes are pruned', g.nodes.every(n => G.degree(g, n.id) > 0))
}

// --------------------------------------------------------------- lane model
section('lanemodel: derivation')
{
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    const net = L.derive(g)
    eq('a lone road has two lanes', net.lanes.length, 2)
    eq('...and no turns', net.connectors.length, 0)
    ok('...both of which are dead ends', net.lanes.every(l => l.terminal))
    eq('stats agree', net.stats.deadEnds, 2)
    // right-hand traffic: driving +x, the lane sits at +z
    const fwd = net.lanes.find(l => l.ux > 0.9)
    ok('the +x lane is offset to +z (right-hand traffic)', fwd.z0 > 0,
       'z0=' + fwd.z0)
    near('...by half a lane width', fwd.z0, L.LANE_W * 0.5, 1e-6)
    const bwd = net.lanes.find(l => l.ux < -0.9)
    near('the -x lane mirrors it', bwd.z0, -L.LANE_W * 0.5, 1e-6)
}
{
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    G.insertRoad(g, 30, -30, 30, 30, {})
    const net = L.derive(g)
    eq('a crossing has eight lanes', net.lanes.length, 8)
    // 4 arriving lanes, each reaching the 3 other roads
    eq('...and twelve turns', net.connectors.length, 12)
    const mid = net.nodes.find(n => n.degree === 4)
    ok('the box has a radius', mid.radius > 0, 'radius=' + mid.radius)
    near('...of one half-width at a right angle', mid.radius, L.LANE_W, 1e-6)
    const turns = net.connectors.map(c => c.turn).sort()
    eq('four straights', turns.filter(t => t === 'straight').length, 4)
    eq('four lefts', turns.filter(t => t === 'left').length, 4)
    eq('four rights', turns.filter(t => t === 'right').length, 4)
    ok('crossing turns conflict with something',
       net.connectors.filter(c => c.conflicts.length > 0).length > 0)
    const straight = net.connectors.find(c => c.turn === 'straight')
    ok('a straight-through conflicts with the cross traffic',
       straight.conflicts.length > 0)
    const right = net.connectors.find(c => c.turn === 'right')
    ok('a right turn conflicts with less than a left',
       right.conflicts.length <= net.connectors.find(c => c.turn === 'left').conflicts.length,
       'right=' + right.conflicts.length + ' left=' +
       net.connectors.find(c => c.turn === 'left').conflicts.length)
    ok('no lane at a 4-way is a dead end',
       net.lanes.filter(l => l.terminal).length === 4)   // the four outer stubs
}
{
    // a straight-through degree-2 node needs no junction box at all
    const g = G.empty()
    const a = G.addNode(g, 0, 0), b = G.addNode(g, 40, 0), c = G.addNode(g, 80, 0)
    g.roads.push({ id: g.nextId++, a: a.id, b: b.id, lanes: 1 })
    g.roads.push({ id: g.nextId++, a: b.id, b: c.id, lanes: 1 })
    const net = L.derive(g)
    const mid = net.nodes.find(n => n.id === b.id)
    near('a collinear joint has no box', mid.radius, 0, 1e-9)
    eq('...but still connects the lanes', net.connectors.length, 2)
}
{
    // a right-angle bend DOES need one
    const g = G.empty()
    G.insertRoad(g, 0, 0, 40, 0, {})
    G.insertRoad(g, 40, 0, 40, 40, {})
    const net = L.derive(g)
    const corner = net.nodes.find(n => n.degree === 2)
    near('a 90-degree bend gets a box', corner.radius, L.LANE_W, 1e-6)
}
{
    // two lanes per direction: the fan must stay one connector per road
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, { lanes: 2 })
    G.insertRoad(g, 30, -30, 30, 30, { lanes: 2 })
    const net = L.derive(g)
    eq('four lanes per road', net.lanes.length, 16)
    eq('one turn per arriving lane per other road', net.connectors.length, 8 * 3)
}
{
    // poseOn must walk a lane and a curve without leaving the geometry
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    G.insertRoad(g, 30, -30, 30, 30, {})
    const net = L.derive(g)
    const lane = net.lanes[0]
    const p0 = L.poseOn(net, 0, 0, 0)
    const p1 = L.poseOn(net, 0, 0, lane.length)
    near('pose at s=0 is the lane start (x)', p0.x, lane.x0, 1e-6)
    near('pose at s=len is the lane end (x)', p1.x, lane.x1, 1e-6)
    near('pose at s=len is the lane end (z)', p1.z, lane.z1, 1e-6)
    const conn = net.connectors[0]
    const c0 = L.poseOn(net, 1, 0, 0)
    const c1 = L.poseOn(net, 1, 0, conn.length)
    near('curve starts at its lane end', Math.hypot(
        c0.x - net.lanes[conn.fromLane].x1, c0.z - net.lanes[conn.fromLane].z1), 0, 1e-6)
    near('curve ends at the next lane start', Math.hypot(
        c1.x - net.lanes[conn.toLane].x0, c1.z - net.lanes[conn.toLane].z0), 0, 1e-6)
}
{
    // render runs must be plain numbers - no Qt in a pragma library
    const g = G.empty()
    G.insertRoad(g, 0, 0, 60, 0, {})
    const net = L.derive(g)
    const runs = L.surfaceRuns(net, '#888')
    eq('one ribbon per road', runs.length, 1)
    ok('a run is flat numbers', runs[0].xz.every(v => typeof v === 'number'))
    const lr = L.laneRuns(net, {})
    ok('lane runs are flat numbers too',
       lr.every(r => r.xz.every(v => typeof v === 'number')))
}

// ------------------------------------------------------------------ turn bans
section('turn bans: directed, per road pair, still drawn')
function crossing() {
    const g = G.empty()
    G.insertRoad(g, -90, 0, 90, 0, {})
    G.insertRoad(g, 0, -60, 0, 60, {})
    return g
}
{
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    const A = legs[0].id, B = legs[1].id

    ok('nothing is banned to start with', !G.isBanned(g, hub.id, A, B))
    ok('toggling returns the new state', G.toggleBanned(g, hub.id, A, B) === true)
    ok('...and it took', G.isBanned(g, hub.id, A, B))
    // THE point of the user-facing design: a ban is DIRECTED
    ok('the reverse movement is untouched', !G.isBanned(g, hub.id, B, A))
    G.setBanned(g, hub.id, B, A, true)
    ok('...and can be banned independently', G.isBanned(g, hub.id, B, A))
    G.setBanned(g, hub.id, A, B, false)
    ok('lifting one leaves the other', !G.isBanned(g, hub.id, A, B)
       && G.isBanned(g, hub.id, B, A))
    ok('a ban survives a clone', G.isBanned(G.clone(g), hub.id, B, A))
}
{
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    const A = legs[0].id, B = legs[1].id
    const before = L.derive(g)
    const liveBefore = before.lanes.reduce((s, l) => s + l.exits.length, 0)

    G.setBanned(g, hub.id, A, B, true)
    const after = L.derive(g)
    eq('the connector still exists', after.connectors.length, before.connectors.length)
    eq('...and is marked banned', after.stats.bannedTurns, 1)
    const banned = after.connectors.find(c => c.banned)
    ok('the banned turn knows its roads', banned.fromRoad === A && banned.toRoad === B)
    eq('...and is no longer an exit',
       after.lanes.reduce((s, l) => s + l.exits.length, 0), liveBefore - 1)
    ok('no lane lists it', after.lanes.every(l => l.exits.indexOf(banned.id) === -1))
    ok('a banned turn is in nobody\'s conflict set',
       after.connectors.every(c => c.conflicts.indexOf(banned.id) === -1))
    ok('...and holds no conflicts of its own', banned.conflicts.length === 0)
}
{
    // ban every exit from one lane and that lane becomes a dead end - the
    // consequence that makes bans a modelling tool and not just a decoration
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    const arriving = legs[0].id
    const deadBefore = L.derive(g).stats.deadEnds
    for (const other of legs) {
        if (other.id === arriving) continue
        G.setBanned(g, hub.id, arriving, other.id, true)
    }
    const net = L.derive(g)
    eq('banning every exit makes the lane a dead end', net.stats.deadEnds, deadBefore + 1)
    eq('...and bans three movements', net.stats.bannedTurns, 3)
}
{
    // a ban keyed on roads must survive everything that re-derives
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    G.setBanned(g, hub.id, legs[0].id, legs[1].id, true)
    G.setLanes(g, legs[0].id, 2)
    eq('a ban survives a lane-count change', L.derive(g).stats.bannedTurns, 2)
    const n = G.nodeById(g, hub.id)
    n.x += 4; n.z -= 3
    ok('...and a node move', L.derive(g).stats.bannedTurns > 0)
}
{
    // splitting the banned road must carry the ban onto the half that still
    // reaches the junction, not silently drop it
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    const from = legs[0], to = legs[1]
    G.setBanned(g, hub.id, from.id, to.id, true)
    eq('banned before the split', L.derive(g).stats.bannedTurns, 1)
    // cut the banned road somewhere along its length
    const a = G.nodeById(g, from.a), b = G.nodeById(g, from.b)
    G.splitRoad(g, from.id, (a.x + b.x) / 2, (a.z + b.z) / 2)
    ok('the ban follows the half that still reaches the junction',
       L.derive(g).stats.bannedTurns === 1)
}
{
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    G.setBanned(g, hub.id, legs[0].id, legs[1].id, true)
    G.removeRoad(g, legs[1].id)
    eq('removing a road prunes bans naming it', (g.bans || []).length, 0)
}
{
    // and the sim must actually honour it
    const g = crossing()
    const hub = G.nearestNode(g, 0, 0, 1)
    const legs = G.incident(g, hub.id)
    for (const other of legs) {
        if (other.id === legs[0].id) continue
        G.setBanned(g, hub.id, legs[0].id, other.id, true)
    }
    const net = L.derive(g)
    const bannedIds = net.connectors.filter(c => c.banned).map(c => c.id)
    const st = T.createState()
    const rng = rngFrom(5)
    const p = Object.assign(T.defaultParams(), { demand: 0.6 })
    let everUsed = 0
    for (let i = 0; i < 3600; ++i) {
        T.step(net, st, 1 / 60, rng, p)
        for (const c of st.cars)
            if (c.kind === 1 && bannedIds.indexOf(c.idx) !== -1) ++everUsed
    }
    eq('no car ever enters a banned turn', everUsed, 0)
    ok('...and traffic still runs', T.meanSpeed(st) > 3,
       'meanSpeed=' + T.meanSpeed(st).toFixed(2))
}

// ------------------------------------------------------------------ traffic
section('traffic: the sim')
function grid() {
    // a 3x3 lattice: interior crossings, and eight stubs that are dead ends
    const g = G.empty()
    for (let i = 0; i < 3; ++i) {
        G.insertRoad(g, -20 + i * 60, -80, -20 + i * 60, 80, {})
        G.insertRoad(g, -80, -20 + i * 60, 80, -20 + i * 60, {})
    }
    return g
}
function run(seed, steps, par, netIn) {
    const net = netIn || L.derive(grid())
    const st = T.createState()
    const rng = rngFrom(seed)
    const p = Object.assign(T.defaultParams(), par || {})
    for (let i = 0; i < steps; ++i) T.step(net, st, 1 / 60, rng, p)
    return { net, st, p }
}
{
    const { net } = run(42, 1)
    ok('the lattice has interior crossings', net.stats.junctions >= 4,
       'junctions=' + net.stats.junctions)
    ok('...and dead-end stubs', net.stats.deadEnds > 0)
}
{
    const { net, st, p } = run(42, 600)   // 10 sim seconds
    ok('cars appeared', st.cars.length > 0, 'cars=' + st.cars.length)
    ok('...up to the target', st.cars.length <= T.targetCount(net, p))
    ok('...and they are moving', T.meanSpeed(st) > 1,
       'meanSpeed=' + T.meanSpeed(st).toFixed(2))
    ok('every car is on a real element', st.cars.every(c =>
        c.kind === 0 ? c.idx < net.lanes.length : c.idx < net.connectors.length))
    ok('nobody is off the end of its element', st.cars.every(c =>
        c.s >= -1e-6 && c.s <= L.elementLength(net, c.kind, c.idx) + 1e-6))
    ok('alpha stays in range', st.cars.every(c => c.alpha >= 0 && c.alpha <= 1))
}
{
    // THE determinism contract: same seed, same graph, same everything
    const a = run(7, 900)
    const b = run(7, 900)
    const norm = s => JSON.stringify(s.cars.map(c =>
        [c.kind, c.idx, +c.s.toFixed(9), +c.v.toFixed(9)]))
    ok('two identical runs are byte-identical', norm(a.st) === norm(b.st))
    ok('...including the counters',
       a.st.spawned === b.st.spawned && a.st.gone === b.st.gone)
    const c = run(8, 900)
    ok('a different seed diverges', norm(a.st) !== norm(c.st))
}
{
    // no two cars may occupy the same spot on the same element
    const { net, st, p } = run(11, 1800)
    let worst = Infinity, clashes = 0
    const byElem = {}
    for (const c of st.cars) {
        const k = c.kind * 1e6 + c.idx
        ;(byElem[k] = byElem[k] || []).push(c)
    }
    for (const k in byElem) {
        const list = byElem[k].sort((x, y) => x.s - y.s)
        for (let i = 1; i < list.length; ++i) {
            const gap = list[i].s - list[i - 1].s - p.carLen
            worst = Math.min(worst, gap)
            if (gap < -0.05) clashes++
        }
    }
    ok('no car overlaps its leader', clashes === 0,
       'clashes=' + clashes + ' worst gap=' + worst.toFixed(3))
}
{
    // one car may be inside a given turn at a time, and never two conflicting
    const { net, st } = run(13, 1800)
    const inConn = st.cars.filter(c => c.kind === 1)
    const seen = {}
    let dupes = 0, conflicts = 0
    for (const c of inConn) {
        if (seen[c.idx]) dupes++
        seen[c.idx] = c.id
    }
    for (const c of inConn)
        for (const other of net.connectors[c.idx].conflicts)
            if (seen[other] && seen[other] !== c.id) conflicts++
    ok('one car per turn', dupes === 0, 'dupes=' + dupes)
    ok('no two conflicting turns are occupied at once', conflicts === 0,
       'conflicts=' + conflicts)
}
{
    // dead ends must actually consume cars, and the population must hold
    const { net, st, p } = run(17, 3600)
    ok('cars left at dead ends', st.gone > 0, 'gone=' + st.gone)
    ok('the population is maintained', st.cars.length >= T.targetCount(net, p) * 0.5,
       'cars=' + st.cars.length + ' target=' + T.targetCount(net, p))
    ok('traffic keeps flowing', T.stoppedShare(st) < 0.6,
       'stopped=' + (T.stoppedShare(st) * 100).toFixed(0) + '%')
    const rates = net.roads.map(r => st.rate[r.id] || 0)
    ok('roads report a flow rate', rates.some(r => r > 0),
       'max=' + Math.max(...rates).toFixed(1))
}
{
    // a lone dead-end road: everything spawned must eventually drain away
    const g = G.empty()
    G.insertRoad(g, 0, 0, 120, 0, {})
    const net = L.derive(g)
    const st = T.createState()
    const rng = rngFrom(3)
    const p = Object.assign(T.defaultParams(), { demand: 0.4, spawnRate: 0 })
    // seed a few cars by hand, then run with spawning off
    const pSpawn = Object.assign({}, p, { spawnRate: 9 })
    for (let i = 0; i < 120; ++i) T.step(net, st, 1 / 60, rng, pSpawn)
    const seeded = st.cars.length
    ok('a dead-end road still gets cars', seeded > 0, 'seeded=' + seeded)
    for (let i = 0; i < 3600; ++i) T.step(net, st, 1 / 60, rng, p)
    eq('...and they all drive off the end', st.cars.length, 0)
    eq('...counted as gone', st.gone, seeded)
}
{
    // rehome: edit the network under running traffic
    const g = grid()
    const net = L.derive(g)
    const st = T.createState()
    const rng = rngFrom(23)
    const p = T.defaultParams()
    for (let i = 0; i < 1200; ++i) T.step(net, st, 1 / 60, rng, p)
    const before = st.cars.length
    ok('there is traffic to preserve', before > 5, 'cars=' + before)
    // add a road, rebuild, re-home
    G.insertRoad(g, -80, 80, 80, 80, {})
    const net2 = L.derive(g)
    T.rehome(net2, net, st)
    ok('most cars survive an edit', st.cars.length >= before * 0.7,
       'kept=' + st.cars.length + '/' + before)
    ok('re-homed cars sit on valid lanes', st.cars.every(c =>
        c.kind === 0 && c.idx < net2.lanes.length &&
        c.s >= -1e-6 && c.s <= net2.lanes[c.idx].length + 1e-6))
    for (let i = 0; i < 600; ++i) T.step(net2, st, 1 / 60, rng, p)
    ok('...and keep driving afterwards', T.meanSpeed(st) > 1,
       'meanSpeed=' + T.meanSpeed(st).toFixed(2))
}
{
    // deleting the road under a car must not strand it
    const g = G.empty()
    G.insertRoad(g, 0, 0, 120, 0, {})
    G.insertRoad(g, 60, 0, 60, 90, {})
    const net = L.derive(g)
    const st = T.createState()
    const rng = rngFrom(31)
    const p = T.defaultParams()
    for (let i = 0; i < 900; ++i) T.step(net, st, 1 / 60, rng, p)
    const spur = g.roads.find(r => Math.abs(G.nodeById(g, r.a).x - 60) < 1 &&
                                   Math.abs(G.nodeById(g, r.b).x - 60) < 1)
    G.removeRoad(g, spur.id)
    const net2 = L.derive(g)
    T.rehome(net2, net, st)
    ok('cars on a deleted road are dropped, not stranded', st.cars.every(c =>
        c.idx < net2.lanes.length))
    for (let i = 0; i < 600; ++i) T.step(net2, st, 1 / 60, rng, p)
    ok('the sim survives the deletion', st.cars.length > 0)
}
{
    // density must actually govern how many cars there are
    const net = L.derive(grid())
    const lo = run(5, 2400, { demand: 0.15 }, net)
    const hi = run(5, 2400, { demand: 0.9 }, net)
    ok('more density, more cars', hi.st.cars.length > lo.st.cars.length * 1.5,
       'lo=' + lo.st.cars.length + ' hi=' + hi.st.cars.length)
    ok('...and slower going', T.meanSpeed(hi.st) < T.meanSpeed(lo.st),
       'lo=' + T.meanSpeed(lo.st).toFixed(2) + ' hi=' + T.meanSpeed(hi.st).toFixed(2))
}
{
    // REGRESSION: a car must not book a junction while another car sits ahead
    // of it on the same lane. It cannot reach the turn it reserved, and if the
    // car in front then wants a conflicting turn, the two wait on each other
    // for ever. A tree network (no alternative routes) is where this bites.
    const g = G.empty()
    G.insertRoad(g, -100, 0, 100, 0, {})
    G.insertRoad(g, -60, 0, -60, -55, {})
    G.insertRoad(g, -20, 0, -20, 55, {})
    G.insertRoad(g, 20, 0, 20, -55, {})
    G.insertRoad(g, 60, 0, 60, 55, {})
    G.insertRoad(g, -60, -55, -20, -55, {})
    G.insertRoad(g, 20, 55, 60, 55, {})
    const net = L.derive(g)
    // These four (seed, density) pairs all seized up before the fix - the
    // first two completely, at mean speed 0. Kept as the regression: any one
    // of them going still again means a booking is being held by a car that
    // cannot use it.
    const cases = [[55, 0.3], [24, 0.7], [42, 0.4], [25, 0.5]]
    let stuck = 0, worstWait = 0, slowest = Infinity
    let offenders = 0
    for (const [seed, density] of cases) {
        const st = T.createState()
        const rng = rngFrom(seed)
        const p = Object.assign(T.defaultParams(), { demand: density })
        for (let i = 0; i < 3600; ++i) T.step(net, st, 1 / 60, rng, p)
        const w = st.cars.reduce((m, c) => Math.max(m, c.wait), 0)
        const sp = T.meanSpeed(st)
        worstWait = Math.max(worstWait, w)
        slowest = Math.min(slowest, sp)
        if (sp < 3) ++stuck
        // only the car AT the stop line may hold a booking
        for (const c of st.cars) {
            if (c.booked === -1 || c.kind !== 0) continue
            for (const o of st.cars)
                if (o.id !== c.id && o.kind === 0 && o.idx === c.idx && o.s > c.s)
                    ++offenders
        }
    }
    ok('a tree network never seizes up', stuck === 0,
       'stuck runs=' + stuck + '/' + cases.length + ' slowest=' + slowest.toFixed(2))
    ok('...and nobody waits for ever', worstWait < 25,
       'worst wait=' + worstWait.toFixed(1) + 's')
    ok('a booking is never held from behind another car', offenders === 0,
       'offenders=' + offenders)
}
{
    // an empty network must be a no-op, not a crash
    const net = L.derive(G.empty())
    const st = T.createState()
    const rng = rngFrom(1)
    for (let i = 0; i < 60; ++i) T.step(net, st, 1 / 60, rng, T.defaultParams())
    eq('no network, no cars', st.cars.length, 0)
}

console.log('\n' + pass + ' passed, ' + fail + ' failed')
process.exit(fail ? 1 : 0)
