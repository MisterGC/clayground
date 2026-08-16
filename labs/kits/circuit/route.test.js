// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the circuit kit's wire router.
//
//     node labs/kits/circuit/route.test.js
//
// The router is geometry, so what is expensive to get wrong is geometry:
// that every segment it draws is axis-aligned, that a lead leaves its pad on
// the pad's own side, that a wire between two pads already in line is still
// the straight one (every rail on every preset board is that case), and that
// the path arithmetic the hit test and the junction drop depend on agrees
// with the path that was drawn.
const K = require('../kitcheck.js')

const R = K.load(__dirname, 'route.js',
                 ['routeOne', 'routeAll', 'clean', 'pathLength',
                  'closestOnPath', 'midOfPath', 'occupancy', 'scorePath'])

const L = (x, z) => ({ x: x, z: z })
const pad = (x, z, dx, dz) =>
    ({ x: x, z: z, dir: (dx === undefined ? null : { x: dx, z: dz }) })

// Every segment axis-aligned is THE property: a path that fails this is not a
// Manhattan route whatever else it gets right.
function orthogonal(pts) {
    for (let i = 0; i + 1 < pts.length; ++i) {
        const a = pts[i], b = pts[i + 1]
        if (Math.abs(a.x - b.x) > 1e-6 && Math.abs(a.z - b.z) > 1e-6) return false
    }
    return true
}
function bends(pts) { return Math.max(0, pts.length - 2) }
function ends(pts, a, b) {
    const f = pts[0], l = pts[pts.length - 1]
    return Math.abs(f.x - a.x) < 1e-6 && Math.abs(f.z - a.z) < 1e-6
        && Math.abs(l.x - b.x) < 1e-6 && Math.abs(l.z - b.z) < 1e-6
}
// The direction the path leaves its first point in.
function outDir(pts) {
    return { x: Math.sign(pts[1].x - pts[0].x), z: Math.sign(pts[1].z - pts[0].z) }
}

// ------------------------------------------------------------------ clean
K.section('path cleaning')
{
    const p = R.clean([L(0, 0), L(0, 0), L(10, 0)])
    K.eq('a repeated point is dropped', p.length, 2)
}
{
    const p = R.clean([L(0, 0), L(5, 0), L(10, 0)])
    K.eq('a collinear middle is dropped', p.length, 2)
    K.eq('and the ends survive it', p[1].x, 10)
}
{
    const p = R.clean([L(0, 0), L(10, 0), L(10, 8)])
    K.eq('a real corner is kept', p.length, 3)
}
{
    const p = R.clean([L(3, 4)])
    K.eq('a single point cleans to itself', p.length, 1)
}

// ------------------------------------------------------------------ arithmetic
K.section('path arithmetic')
{
    const p = [L(0, 0), L(6, 0), L(6, 8)]
    K.near('length adds up along the corners', R.pathLength(p), 14)
    const m = R.midOfPath(p)
    K.near('the midpoint is half the LENGTH along, not the mean of the ends',
           m.x, 6, 1e-6)
    K.near('and lands on the second leg', m.z, 1, 1e-6)
}
{
    const p = [L(0, 0), L(10, 0), L(10, 10)]
    const c = R.closestOnPath(p, 11, 4)
    K.near('the nearest point on an L is on the leg beside it', c.x, 10, 1e-6)
    K.near('at the height it was asked about', c.z, 4, 1e-6)
    K.near('and reports how far off the wire the click was', c.dist, 1, 1e-6)
}
{
    // a click nowhere near either leg still returns the nearest point, which
    // is what lets the hit test reject it by distance rather than by luck
    const c = R.closestOnPath([L(0, 0), L(10, 0)], 5, 40)
    K.near('a distant click reports its true distance', c.dist, 40, 1e-6)
}

// ------------------------------------------------------------------ in line
K.section('pads already in line')
{
    const p = R.routeOne(pad(0, 0, 1, 0), pad(20, 0, -1, 0), [], null, 2.5)
    K.eq('two pads on one row are one straight segment', p.length, 2)
    K.ok('and it still ends where it should', ends(p, L(0, 0), L(20, 0)))
}
{
    const p = R.routeOne(pad(0, 0, 0, 1), pad(0, 25, 0, -1), [], null, 2.5)
    K.eq('two pads in one column are one straight segment', p.length, 2)
}
{
    // the rails: a junction to a junction, straight across
    const p = R.routeOne(pad(-30, -20), pad(30, -20), [], null, 2.5)
    K.eq('a rail between two solder dots is untouched', p.length, 2)
}
{
    // within the tolerance, a slope nobody can see beats a jog everybody can
    const p = R.routeOne(pad(0, 0, 1, 0), pad(20, 0.3, -1, 0), [], null, 2.5)
    K.eq('a near-alignment stays straight rather than growing a jog', p.length, 2)
}

// ------------------------------------------------------------------ elbows
K.section('one corner')
{
    // out of the side of one part, into the bottom of another that is sitting
    // above it - so both leads already face one another
    const a = pad(0, 0, 1, 0), b = pad(20, -15, 0, 1)
    const p = R.routeOne(a, b, [], null, 2.5)
    K.ok('every segment is axis-aligned', orthogonal(p))
    K.ok('it ends on both pads', ends(p, L(0, 0), L(20, -15)))
    K.eq('sideways-out into vertically-in needs exactly one corner', bends(p), 1)
    const d = outDir(p)
    K.eq('and the lead leaves along its own side', d.x, 1)
    K.eq('without any sideways drift at the pad', d.z, 0)
}
{
    // the mirror: vertically out, sideways in
    const p = R.routeOne(pad(0, 0, 0, 1), pad(18, 14, -1, 0), [], null, 2.5)
    K.eq('vertically-out into sideways-in is also one corner', bends(p), 1)
    K.eq('leaving downwards', outDir(p).z, 1)
    K.eq('and not sideways', outDir(p).x, 0)
}

// ------------------------------------------------------------------ channels
K.section('two corners')
{
    // both leads on the same axis and the pads on different rows: the route
    // has to change lane somewhere in between
    const p = R.routeOne(pad(0, 0, 1, 0), pad(30, 12, -1, 0), [], null, 2.5)
    K.ok('every segment is axis-aligned', orthogonal(p))
    K.eq('same-axis leads on different rows need two corners', bends(p), 2)
    K.eq('the lead still leaves sideways', outDir(p).x, 1)
    K.near('and the lane it changes in is on the peg raster',
           p[1].x - Math.round(p[1].x / 2.5) * 2.5, 0, 1e-6)
}
{
    // both leads vertical
    const p = R.routeOne(pad(0, 0, 0, -1), pad(14, -30, 0, 1), [], null, 2.5)
    K.eq('two vertical leads need two corners', bends(p), 2)
    K.eq('leaving upwards', outDir(p).z, -1)
}

// ------------------------------------------------------------------ leads
K.section('leads leave their own side')
{
    // the awkward one: B is BEHIND A, so the route has to come out of A's
    // front, turn, and go back past it
    const p = R.routeOne(pad(0, 0, 1, 0), pad(-25, 14, -1, 0), [], null, 2.5)
    K.ok('every segment is axis-aligned', orthogonal(p))
    K.eq('the lead still leaves forwards, not backwards through the part',
         outDir(p).x, 1)
}
{
    // the destination pad's lead points AWAY from where the wire is coming
    // from, so entering it head-on would lay the wire across its own part.
    // The route is expected to come round and arrive along the lead instead.
    const p = R.routeOne(pad(0, 0, 1, 0), pad(20, -15, 0, -1), [], null, 2.5)
    const n = p.length - 1
    const inDir = { x: Math.sign(p[n - 1].x - p[n].x),
                    z: Math.sign(p[n - 1].z - p[n].z) }
    K.eq('the wire arrives along the destination lead, not through the part',
         inDir.z, -1)
    K.ok('and pays for it with corners rather than a diagonal', orthogonal(p))
}
{
    // pads facing each other three units apart must not each grow a lead
    // longer than the gap and overshoot
    const p = R.routeOne(pad(0, 0, 1, 0), pad(3, 6, 0, -1), [], null, 2.5)
    K.ok('a short facing hop stays axis-aligned', orthogonal(p))
    let backwards = false
    for (let i = 0; i + 1 < p.length; ++i)
        if (p[i + 1].x < p[i].x - 1e-6) backwards = true
    K.ok('and never doubles back on itself', !backwards)
}

{
    // in line, but with a part standing between the two pads: a straight wire
    // there would lie across the part, so the route is expected to step over
    // it and come back
    const box = { x: 10, z: 0, hx: 4, hz: 3.4 }
    const p = R.routeOne(pad(0, 0, 1, 0), pad(20, 0, -1, 0), [box], null, 2.5)
    K.ok('a blocked lane is no longer drawn straight through', p.length > 2)
    K.ok('the way round is axis-aligned', orthogonal(p))
    let through = false
    for (let i = 0; i + 1 < p.length; ++i) {
        const a = p[i], b = p[i + 1]
        if (Math.max(a.x, b.x) > box.x - box.hx && Math.min(a.x, b.x) < box.x + box.hx
            && Math.max(a.z, b.z) > box.z - box.hz
            && Math.min(a.z, b.z) < box.z + box.hz) through = true
    }
    K.ok('and it really does clear the part', !through)
}

// ------------------------------------------------------------------ obstacles
K.section('parts in the way')
{
    // a part sitting exactly on the plain elbow's corner
    const box = { x: 20, z: 0, hx: 5, hz: 4 }
    const p = R.routeOne(pad(0, 0, 1, 0), pad(20, -20, 0, -1), [box], null, 2.5)
    K.ok('the detour is still axis-aligned', orthogonal(p))
    let through = false
    for (let i = 0; i + 1 < p.length; ++i) {
        const a = p[i], b = p[i + 1]
        const x0 = Math.min(a.x, b.x), x1 = Math.max(a.x, b.x)
        const z0 = Math.min(a.z, b.z), z1 = Math.max(a.z, b.z)
        if (x1 > box.x - box.hx && x0 < box.x + box.hx
            && z1 > box.z - box.hz && z0 < box.z + box.hz) through = true
    }
    K.ok('and it goes round the part rather than through it', !through)
}
{
    // no way round at all: the router must still answer, and answer with a
    // path, rather than refusing or returning something not orthogonal
    const wall = []
    for (let z = -40; z <= 40; z += 4) wall.push({ x: 10, z: z, hx: 3, hz: 2.5 })
    const p = R.routeOne(pad(0, 0, 1, 0), pad(30, 10, -1, 0), wall, null, 2.5)
    K.ok('a boxed-in wire still gets a path', p.length >= 2)
    K.ok('and it is still axis-aligned', orthogonal(p))
}

// ------------------------------------------------------------------ lanes
K.section('wires sharing a lane')
{
    const links = [
        { id: 1, a: pad(0, 0, 1, 0), b: pad(30, 12, -1, 0), ends: [] },
        { id: 2, a: pad(0, 4, 1, 0), b: pad(30, 16, -1, 0), ends: [] }
    ]
    const res = R.routeAll(links, [], 2.5)
    K.ok('both wires are routed', !!res[1] && !!res[2])
    K.ok('both are axis-aligned', orthogonal(res[1]) && orthogonal(res[2]))
    K.ok('and they do not change lane in the same column',
         Math.abs(res[1][1].x - res[2][1].x) > 1e-6)
}
{
    const t = R.occupancy()
    t.add(L(0, 0), L(10, 0))
    // charged by the unit: six units of this run are hidden under the first
    K.eq('a lane reports how much of a run is buried', t.overlaps(L(4, 0), L(14, 0)), 6)
    K.eq('a lane ignores a run that only touches it at a corner',
         t.overlaps(L(10, 0), L(20, 0)), 0)
    K.eq('a lane ignores a run on a different line',
         t.overlaps(L(0, 5), L(10, 5)), 0)
}

// ------------------------------------------------------------------ boards
K.section('a whole board')
{
    // the shape the logic presets have: two rails, parts on branches between
    // them, plus one cross-connection that is the diagonal this all exists for
    const obstacles = []
    const links = []
    let id = 0
    for (let c = 0; c < 5; ++c) {
        const x = -20 + c * 10
        obstacles.push({ id: 100 + c, x: x, z: 0, hx: 4.6, hz: 3.4 })
        links.push({ id: ++id, a: pad(x, -3.5, 0, -1), b: pad(x, -20),
                     ends: [100 + c, 0] })
        links.push({ id: ++id, a: pad(x, 3.5, 0, 1), b: pad(x, 20),
                     ends: [100 + c, 0] })
    }
    links.push({ id: ++id, a: pad(-20, -3.5, 0, -1), b: pad(20, 3.5, 0, 1),
                 ends: [100, 104] })
    const res = R.routeAll(links, obstacles, 2.5)
    let allOrtho = true, allEnded = true, crossings = 0
    for (const w of links) {
        const p = res[w.id]
        if (!orthogonal(p)) allOrtho = false
        if (!ends(p, L(w.a.x, w.a.z), L(w.b.x, w.b.z))) allEnded = false
        for (let i = 0; i + 1 < p.length; ++i)
            for (const o of obstacles) {
                if (w.ends.indexOf(o.id) >= 0) continue
                const a = p[i], b = p[i + 1]
                if (Math.max(a.x, b.x) > o.x - o.hx && Math.min(a.x, b.x) < o.x + o.hx
                    && Math.max(a.z, b.z) > o.z - o.hz
                    && Math.min(a.z, b.z) < o.z + o.hz) ++crossings
            }
    }
    K.ok('every wire on the board is axis-aligned', allOrtho)
    K.ok('every wire still ends on its two pads', allEnded)
    K.eq('and no wire crosses a part it is not wired to', crossings, 0)
}
{
    // determinism: the board is redrawn on every move, and a route that
    // wandered between two identical inputs would make the board flicker
    const links = [
        { id: 1, a: pad(0, 0, 1, 0), b: pad(30, 12, -1, 0), ends: [] },
        { id: 2, a: pad(0, 8, 1, 0), b: pad(30, -6, -1, 0), ends: [] }
    ]
    const obs = [{ id: 9, x: 15, z: 4, hx: 5, hz: 4 }]
    const one = JSON.stringify(R.routeAll(links, obs, 2.5))
    const two = JSON.stringify(R.routeAll(links, obs, 2.5))
    K.eq('the same board routes to the same paths', one, two)
}

process.exit(K.report('circuit router'))
