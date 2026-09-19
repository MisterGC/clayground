// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Where the charge carriers are inside the die, as a pure function of time.
//
// The dive-in's whole claim is that a transistor's inside can be WATCHED: a
// base current is not a number on a panel but a thin stream coming in from the
// side that lets a thick stream through from top to bottom. That claim only
// holds if the motion is the lab's own numbers, so this file is the model and
// nothing else - the QML draws what it is told here.
//
// Qt-free on purpose (`node carriers.test.js`): no vector3d, no clock, no
// Math.random. `carriersAt(t, iB, iC, n)` is a function, not a simulation -
// same arguments, same array, on any machine and in any order. That is also
// what makes "zero current means frozen" checkable rather than a claim about a
// picture: with iC 0 the emitter stream's speed is 0 and every carrier stays
// on the parameter its own hash gave it.
//
// Coordinates are DIE-LOCAL: the die's bottom face is y 0, the footprint is
// centred on x and z, and the units are the circuit kit's board units (the die
// is 1.6 across, see anatomy.js DIE). The QML positions the node; nothing here
// knows where the die stands.

// The die as this file needs it: thicknesses as plain numbers rather than
// anatomy.js's per-layer objects, because every path calculation below wants
// the y of a junction and not a doping. The suite checks the two agree - one
// of them changing alone is exactly the bug that would make the carriers
// travel through the wrong layer.
function defaultDims() {
    return {
        footprint: 1.6,
        layers: { collector: 0.6, base: 0.2, emitter: 0.4 },
        emitterFootprint: 0.9
    }
}

// The y of every interface, bottom to top: the die's floor, the B-C junction,
// the E-B junction and the emitter's top face (where the contact sits).
function levels(dims) {
    const d = dims || defaultDims()
    const bc = d.layers.collector
    const eb = bc + d.layers.base
    return { bottom: 0, bc: bc, eb: eb, top: eb + d.layers.emitter }
}

// How many paths of each kind there are. Fanned across the emitter island
// rather than bundled: five streams read as a current where one reads as a
// bead on a wire, and the fan is what makes the island's footprint - the
// reason a transistor's top layer is small - visible.
var E_PATHS = 5
var B_PATHS = 3

// The polylines carriers ride, in die-local coordinates.
//
// "e" paths are the emitter current: they start ON the island's top face,
// drop through the emitter, cross the thin base (where they bend - the base
// is the layer that deflects them, and a dead straight line through it says
// the base does nothing) and end well inside the collector body, fanning out
// as they go, because the collector is wide and the island is not.
//
// "b" paths are the base current: they come in horizontally at mid-base
// height from the +x edge of the base layer - the side the base contact is on
// in TransistorInterior3D - and stop under the island. Horizontal on purpose:
// the one thing a learner has to see is that the small current goes in
// SIDEWAYS while the big one goes THROUGH.
function paths(dims) {
    const d = dims || defaultDims()
    const L = levels(d)
    const half = d.footprint / 2
    const isleHalf = d.emitterFootprint / 2
    const out = []

    // The fan's outermost start, kept inside the island so no carrier is ever
    // drawn hanging in the air beside it.
    const startHalf = isleHalf * 0.8
    for (let i = 0; i < E_PATHS; ++i) {
        const sx = E_PATHS === 1 ? 0
                 : -startHalf + (2 * startHalf) * (i / (E_PATHS - 1))
        // A little depth, so the fan is a fan and not a row seen edge-on.
        const sz = ((i % 3) - 1) * (isleHalf * 0.24)
        // Which way this path leans while crossing the base. Alternating and
        // derived from the index: a hash would do, but two neighbours leaning
        // apart is what makes the crossing legible.
        const bend = (i % 2 === 0 ? 1 : -1) * d.footprint * 0.03
        const ex = Math.max(-half * 0.85, Math.min(half * 0.85, sx * 1.9))
        out.push({
            kind: "e",
            points: [
                { x: sx, y: L.top, z: sz },
                { x: sx, y: L.eb, z: sz },
                { x: sx + bend, y: (L.eb + L.bc) / 2, z: sz },
                { x: sx * 1.25, y: L.bc, z: sz * 1.1 },
                { x: (sx * 1.25 + ex) / 2, y: L.bc * 0.55, z: sz * 1.3 },
                { x: ex, y: L.bc * 0.2, z: sz * 1.4 }
            ]
        })
    }

    // Mid-base, three sheets deep, each ending under the island's middle.
    const midBase = (L.bc + L.eb) / 2
    const spread = d.layers.base * 0.3
    for (let j = 0; j < B_PATHS; ++j) {
        const dz = (B_PATHS === 1 ? 0 : (j / (B_PATHS - 1)) * 2 - 1) * isleHalf * 0.3
        const y = midBase + (B_PATHS === 1 ? 0 : ((j / (B_PATHS - 1)) * 2 - 1)) * spread
        out.push({
            kind: "b",
            points: [
                { x: half, y: y, z: dz },
                { x: half * 0.55, y: y, z: dz * 0.7 },
                { x: half * 0.1, y: y, z: dz * 0.3 },
                { x: 0, y: y, z: 0 }
            ]
        })
    }
    return out
}

// Cumulative arc length of a polyline, so a carrier at u = 0.5 is half the
// way ALONG it rather than half way through its corner list - the fan's
// segments differ in length by a factor of three and evenly spaced corners
// would make carriers sprint through the base and crawl in the collector.
function arcs(pts) {
    const acc = [0]
    let total = 0
    for (let i = 1; i < pts.length; ++i) {
        const a = pts[i - 1], b = pts[i]
        total += Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z)
        acc.push(total)
    }
    return { acc: acc, total: total }
}

// Where u (0..1) along a polyline is, by arc length.
function pointOn(pts, u) {
    const a = arcs(pts)
    if (a.total <= 0) return { x: pts[0].x, y: pts[0].y, z: pts[0].z }
    const want = Math.max(0, Math.min(1, u)) * a.total
    for (let i = 1; i < a.acc.length; ++i) {
        if (want > a.acc[i] && i < a.acc.length - 1) continue
        const seg = a.acc[i] - a.acc[i - 1]
        const f = seg <= 0 ? 0 : (want - a.acc[i - 1]) / seg
        const p = pts[i - 1], q = pts[i]
        return { x: p.x + (q.x - p.x) * f,
                 y: p.y + (q.y - p.y) * f,
                 z: p.z + (q.z - p.z) * f }
    }
    const last = pts[pts.length - 1]
    return { x: last.x, y: last.y, z: last.z }
}

// Carrier k's place in the queue on its path: a hash, not a random number, so
// the stream is evenly broken up and the same k is in the same place in every
// process. Knuth's multiplicative constant, kept in integer range by the
// modulo - k is at most a few hundred.
function phase(k) {
    return ((k * 2654435761) % 1000) / 1000
}

// How the n carriers split between the two currents. At most half of them are
// base carriers however hard the base is driven: the emitter stream IS the
// thing being explained, and a picture where the sideways trickle outnumbers
// it teaches the opposite of the truth.
function shareOf(n, iB, iC) {
    const b = Math.round(n * (iB / (iB + iC + 1e-9)) * 0.5)
    const bb = Math.max(0, Math.min(n, b))
    return { b: bb, e: n - bb }
}

// How fast one kind of carrier rides its path, in path-lengths per second.
// Proportional to its own current and nothing else, so a current of zero is a
// frozen stream rather than a slow one - "nothing is moving" is the picture a
// transistor in cut-off has to produce.
function speedOf(kind, iB, iC) {
    return 0.6 * (kind === "b" ? iB : iC)
}

// Every carrier at time t: `[{x, y, z, kind}]`, die-local.
//
// Carriers are handed out to paths in two blocks - the emitter ones first,
// then the base ones - rather than by one k % paths.length over the whole
// list, because the split between the two kinds moves with the currents and a
// single modulo would re-assign every carrier to a different path each time
// the base current changed.
function carriersAt(t, iB, iC, n) {
    const count = n === undefined ? 48 : Math.max(0, Math.round(n))
    const b = iB === undefined ? 0 : iB
    const c = iC === undefined ? 0 : iC
    const all = paths()
    const es = [], bs = []
    for (let i = 0; i < all.length; ++i)
        (all[i].kind === "b" ? bs : es).push(all[i])
    const split = shareOf(count, b, c)
    const out = []
    for (let k = 0; k < count; ++k) {
        const isB = k >= split.e && bs.length > 0
        const lane = isB ? bs[(k - split.e) % bs.length] : es[k % es.length]
        const u = _frac(phase(k) + t * speedOf(lane.kind, b, c))
        const p = pointOn(lane.points, u)
        out.push({ x: p.x, y: p.y, z: p.z, kind: lane.kind })
    }
    return out
}

// Positive fractional part: a negative time must still land inside the path.
function _frac(v) {
    return v - Math.floor(v)
}
