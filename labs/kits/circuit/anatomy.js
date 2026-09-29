// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The circuit kit's own part table: the NPN transistor as a thing WITH
// PARTS, and the one description every mechanism resolves a part through -
// the exploded view (TransistorAnatomy3D), the marks a lesson puts on the
// picture, and the camera that has to frame what is coming apart. One file,
// so the teaching order, the travel and where a mark lands are decided once
// instead of per mechanism.
//
// Qt-free on purpose (no vector3d, no clock): `node anatomy.test.js` checks
// it in a second, and the QML side lifts the plain {x, y, z} triples - a row
// goes straight into an ExplodePart's `row` property.
//
// Units are the circuit kit's board units: the TO-92 body is 4.2 across and
// 3.1 tall, the three pads sit 3.5 from the part's centre (see
// CircuitElement3D.qml, termAt()). Everything INSIDE the case is teaching
// geometry, not a datasheet: a real die is a tenth of the package and its
// layers are microns thick; here the die is a third of the body and the
// three layers are thick enough for a finger to land on each.

// Where the legs meet the board - identical to the kit's pads, so the
// anatomy stands exactly where CircuitElement3D's transistor stood.
var PAD_OFFSET = 3.5
var PADS = {
    collector: { x: -PAD_OFFSET, y: 0.62, z: 0 },
    base:      { x: 0,           y: 0.62, z: PAD_OFFSET },
    emitter:   { x: PAD_OFFSET,  y: 0.62, z: 0 }
}

// The case as the kit draws it: a cylinder standing on the board, its axis a
// little behind the part's centre, and a flat face on the base side. Kept
// here so the assembled anatomy is the same silhouette.
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
// mapping (see README.md, "The transistor's anatomy").
var ROLES = ["epoxy", "metal", "gold", "n", "p", "print"]

// Every part, with the displacement it takes at the end of its stage.
//
//   order   place in the lesson (1-based); 0 is drawn but never explained on
//           its own (the print, the header)
//   stage   which interval of the view's spread moves it: 1 travels while
//           spread goes 0 -> 1, 2 while it goes 1 -> 2. The shell and what
//           is outside come off first (legs, case, face, print), then what
//           is inside comes apart (header, die, wires) - otherwise the die
//           climbs out through an epoxy case that is still on it.
//   offset  the whole displacement at the end of its stage, in board units,
//           relative to the assembled pose
//   anchor  where a mark, an assembly line or a fingertip lands, local to
//           the part's own origin - never the origin itself, which for a
//           Box3D is its bottom-centre and sits inside whatever is below
var PARTS = [
    { id: "print",          role: "print", order: 0, stage: 1,
      offset: { x: 0,    y: 0,   z: 0 },
      // Beside the B letter, on the near edge: a mark on the middle of the
      // plate lands under the part it is trying to point past.
      anchor: { x: 0, y: 0.03, z: 3.4 } },
    { id: "leg.collector",  role: "metal", order: 1, stage: 1,
      offset: { x: -1.5, y: 0,   z: 0 },
      // A leg's origin is mid-leg, which is also where a fingertip belongs.
      anchor: { x: 0, y: 0, z: 0 } },
    { id: "leg.base",       role: "metal", order: 2, stage: 1,
      offset: { x: 0,    y: 0,   z: 1.5 },
      anchor: { x: 0, y: 0, z: 0 } },
    { id: "leg.emitter",    role: "metal", order: 3, stage: 1,
      offset: { x: 1.5,  y: 0,   z: 0 },
      anchor: { x: 0, y: 0, z: 0 } },
    { id: "case",           role: "epoxy", order: 4, stage: 1,
      offset: { x: 0,    y: 8.5, z: 0 },
      // Front-top: a ring on the rim reads as "this shell", where a ring on
      // the flank could be on anything behind it.
      anchor: { x: 0, y: BODY.height * 0.5, z: BODY.radius * 0.67 } },
    // The facet flies to the SIDE, not toward the viewer: the rig looks from
    // +z, and a slab that comes forward sits in front of the die it is
    // supposed to reveal (found in the exploded view's first renders).
    { id: "face",           role: "epoxy", order: 0, stage: 1,
      offset: { x: 3.0,  y: 6.5, z: 0.8 },
      anchor: { x: 0, y: 0, z: FACE.depth * 0.5 } },
    { id: "header",         role: "metal", order: 0, stage: 2,
      offset: { x: 0,    y: 1.2, z: 0 },
      anchor: { x: 0, y: HEADER.thickness, z: 0 } },
    // Each die slab's anchor is its TOP face, so a ring on "the base" sits on
    // the surface a learner can see rather than buried in the layer below.
    { id: "die.collector",  role: "n",     order: 5, stage: 2,
      offset: { x: 0,    y: 2.6, z: 0 },
      anchor: { x: 0, y: DIE.layers.collector.thickness, z: 0 } },
    { id: "die.base",       role: "p",     order: 6, stage: 2,
      offset: { x: 0,    y: 3.8, z: 0 },
      anchor: { x: 0, y: DIE.layers.base.thickness, z: 0 } },
    { id: "die.emitter",    role: "n",     order: 7, stage: 2,
      offset: { x: 0,    y: 5.0, z: 0 },
      anchor: { x: 0, y: DIE.layers.emitter.thickness, z: 0 } },
    { id: "wires",          role: "gold",  order: 8, stage: 2,
      offset: { x: 0,    y: 6.2, z: 0 },
      // The arch apex of the emitter wire: the highest point of the pair and
      // the only one not hidden behind a slab from most angles.
      anchor: { x: 0.55, y: 2.70, z: -0.15 } }
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

// The largest stage any part declares - how far `spread` runs.
function stageCount() {
    var n = 1
    for (var i = 0; i < PARTS.length; ++i)
        if (PARTS[i].stage > n) n = PARTS[i].stage
    return n
}

// Displacement of a part at a given spread (0 assembled .. stageCount()
// fully apart), as a plain triple. The same rule ExplodedView3D applies:
// a part travels only while ITS stage is the one opening, so a stage-2 part
// does not move at all until spread passes 1. Linear on purpose: easing is
// the animator's business. No argument means fully apart.
function offsetAt(id, spread) {
    var p = partById(id)
    if (!p) return { x: 0, y: 0, z: 0 }
    var v = spread === undefined || spread === null ? stageCount() : spread
    var stage = p.stage === undefined || p.stage < 1 ? 1 : p.stage
    var t = v - (stage - 1)
    t = t < 0 ? 0 : (t > 1 ? 1 : t)
    return { x: p.offset.x * t, y: p.offset.y * t, z: p.offset.z * t }
}

// The assembled die stack, bottom to top, as y ranges above the header's
// top face: what both the exploded view and any interior build from.
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

// Sanity: ids unique, roles known, order dense, stages whole and at least 1,
// every offset and anchor finite. Returns a list of problems; empty means
// fine. The kernel's own explode.js validate() checks the same table against
// the rules ExplodedView3D relies on; this one adds what only the kit knows
// (the role names).
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
        if (p.stage !== Math.floor(p.stage) || p.stage < 1)
            problems.push("stage below 1 on " + p.id)
        var o = p.offset
        if (!isFinite(o.x) || !isFinite(o.y) || !isFinite(o.z))
            problems.push("non-finite offset on " + p.id)
        var a = p.anchor
        if (!a || !isFinite(a.x) || !isFinite(a.y) || !isFinite(a.z))
            problems.push("non-finite anchor on " + p.id)
    }
    orders.sort(function (a, b) { return a - b })
    for (var k = 0; k < orders.length; ++k)
        if (orders[k] !== k + 1) { problems.push("order is not 1.." + orders.length); break }
    return problems
}
