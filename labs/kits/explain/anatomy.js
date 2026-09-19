// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The NPN transistor as a thing with parts - the ONE description every
// mechanism in this kit explains from, so the exploded view, the callouts,
// the chalk drawing and the interior all agree about what a transistor is
// made of and in which order it is taught.
//
// Qt-free on purpose (no vector3d, no clock): `node anatomy.test.js` checks
// it in a second, and the QML side lifts the plain {x, y, z} triples.
//
// Units are the circuit kit's board units: the TO-92 body is 4.2 across and
// 3.1 tall, the three pads sit 3.5 from the part's centre (see
// labs/kits/circuit/CircuitElement3D.qml, termAt()). Everything INSIDE the
// case is teaching geometry, not a datasheet: a real die is a tenth of the
// package and its layers are microns thick; here the die is a third of the
// body and the three layers are thick enough for a finger to land on each.

// Where the legs meet the board - identical to the circuit kit's pads, so
// the anatomy can stand exactly where a CircuitElement3D "transistor" stood.
var PAD_OFFSET = 3.5
var PADS = {
    collector: { x: -PAD_OFFSET, y: 0.62, z: 0 },
    base:      { x: 0,           y: 0.62, z: PAD_OFFSET },
    emitter:   { x: PAD_OFFSET,  y: 0.62, z: 0 }
}

// The case as the circuit kit draws it: a cylinder standing on the board,
// its axis a little behind the part's centre, and a flat face on the base
// side. Kept here so the assembled anatomy is the same silhouette.
var BODY = { radius: 2.1, height: 3.1, centreZ: -0.35 }
var FACE = { width: 3.8, height: 3.1, depth: 1.2, centreZ: 0.85 }

// The teaching die: a slab of silicon on the collector lead's header, three
// layers stacked N - P - N with the collector at the bottom (it IS the
// substrate), a thin base and a small emitter island on top.
var HEADER = { width: 1.9, thickness: 0.2, depth: 1.9 }
var DIE = {
    footprint: 1.6,
    layers: {
        collector: { doping: "n", thickness: 0.6 },
        base:      { doping: "p", thickness: 0.2 },
        emitter:   { doping: "n", thickness: 0.4, footprint: 0.9 }
    }
}

// Roles name a theme token or a physical colour; the QML side owns the
// mapping (see README.md, "Colour by role").
var ROLES = ["epoxy", "metal", "gold", "n", "p", "print"]

// Every part, with the displacement it takes at full spread. `order` is the
// position in the lesson (1-based); a part with order 0 is drawn but never
// explained on its own (the print, the header). `offset` is the whole
// displacement at spread 1, in board units, relative to the assembled pose.
var PARTS = [
    { id: "print",          role: "print", order: 0, offset: { x: 0,    y: 0,   z: 0 } },
    { id: "leg.collector",  role: "metal", order: 1, offset: { x: -1.5, y: 0,   z: 0 } },
    { id: "leg.base",       role: "metal", order: 2, offset: { x: 0,    y: 0,   z: 1.5 } },
    { id: "leg.emitter",    role: "metal", order: 3, offset: { x: 1.5,  y: 0,   z: 0 } },
    { id: "case",           role: "epoxy", order: 4, offset: { x: 0,    y: 8.5, z: 0 } },
    { id: "face",           role: "epoxy", order: 0, offset: { x: 0,    y: 7.0, z: 3.0 } },
    { id: "header",         role: "metal", order: 0, offset: { x: 0,    y: 1.2, z: 0 } },
    { id: "die.collector",  role: "n",     order: 5, offset: { x: 0,    y: 2.6, z: 0 } },
    { id: "die.base",       role: "p",     order: 6, offset: { x: 0,    y: 3.8, z: 0 } },
    { id: "die.emitter",    role: "n",     order: 7, offset: { x: 0,    y: 5.0, z: 0 } },
    { id: "wires",          role: "gold",  order: 8, offset: { x: 0,    y: 6.2, z: 0 } }
]

function partById(id) {
    for (var i = 0; i < PARTS.length; ++i)
        if (PARTS[i].id === id) return PARTS[i]
    return null
}

function partIds() {
    var out = []
    for (var i = 0; i < PARTS.length; ++i) out.push(PARTS[i].id)
    return out
}

// The ids a lesson walks, in teaching order.
function explainOrder() {
    var withOrder = PARTS.filter(function (p) { return p.order > 0 })
    withOrder.sort(function (a, b) { return a.order - b.order })
    return withOrder.map(function (p) { return p.id })
}

// Displacement of a part at a given spread (0 assembled .. 1 exploded), as
// a plain triple. Linear on purpose: easing is the animator's business.
function offsetAt(id, spread) {
    var p = partById(id)
    if (!p) return { x: 0, y: 0, z: 0 }
    var s = Math.max(0, Math.min(1, spread === undefined ? 1 : spread))
    return { x: p.offset.x * s, y: p.offset.y * s, z: p.offset.z * s }
}

// The assembled die stack, bottom to top, as y ranges above the header's
// top face: what both the exploded view and the interior build from.
function dieStack(baseY) {
    var y = baseY === undefined ? 0 : baseY
    var out = []
    var names = ["collector", "base", "emitter"]
    for (var i = 0; i < names.length; ++i) {
        var l = DIE.layers[names[i]]
        out.push({ layer: names[i], doping: l.doping, y0: y, y1: y + l.thickness,
                   footprint: l.footprint === undefined ? DIE.footprint : l.footprint })
        y += l.thickness
    }
    return out
}

// Sanity: ids unique, roles known, order dense, every offset finite.
// Returns a list of problems; empty means fine.
function validate() {
    var problems = []
    var seen = {}
    var orders = []
    for (var i = 0; i < PARTS.length; ++i) {
        var p = PARTS[i]
        if (seen[p.id]) problems.push("duplicate id " + p.id)
        seen[p.id] = true
        if (ROLES.indexOf(p.role) < 0) problems.push("unknown role " + p.role + " on " + p.id)
        if (p.order > 0) orders.push(p.order)
        var o = p.offset
        if (!isFinite(o.x) || !isFinite(o.y) || !isFinite(o.z))
            problems.push("non-finite offset on " + p.id)
    }
    orders.sort(function (a, b) { return a - b })
    for (var k = 0; k < orders.length; ++k)
        if (orders[k] !== k + 1) { problems.push("order is not 1.." + orders.length); break }
    return problems
}
