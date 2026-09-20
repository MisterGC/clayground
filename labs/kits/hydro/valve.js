// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The valve as a thing with parts - the hydro kit's OWN part table, the one
// every mechanism resolves the valve's parts through: the exploded anatomy,
// a mark, a fingertip, a camera that has to hold the whole explosion.
// HydroElement3D draws the same pieces from the same numbers, so the valve a
// learner operates on the board and the valve that comes apart are one part.
//
// Qt-free on purpose (no vector3d, no clock): `node labs/kits/hydro/valve.js`'s
// suite checks it in a second, and the kernel's own explode.js validates the
// very same rows before a Model is built from them.
//
// Units are the kit's board units - the ones parts.js pins: a two-terminal
// part is 9.2 x 6.8 with its pads at x = -/+3.5, and this valve's body is
// 5.0 x 3.0 inside that footprint. Every constant below is a number the
// component already drew with; nothing here is new geometry.

// The cast body: a box standing on the board, sunk 0.05 into it like every
// other hydro body.
var BODY = { width: 5.0, height: 1.5, depth: 3.0, y: 0.05 }

// The two pipe flanges, discs on the body's left and right faces, their axis
// along x (a #Cylinder stands along y, so the component tips them onto x).
var FLANGE = { x: 2.6, y: 0.75, radius: 0.85, length: 0.6 }

// The rising stem between body and handwheel.
var STEM = { y: 2.0, radius: 0.2, height: 0.8 }

// The handwheel: a rim on two crossed spokes, the whole thing turning a
// quarter about its own axis when the valve is operated.
var WHEEL = {
    y: 2.7, rimRadius: 1.3, rimHeight: 0.3,
    spokeSpan: 5.0, spokeWidth: 0.5, spokeHeight: 0.28, spokeY: -0.14
}

// The printed state plate lying flat on the body's top, on the near side -
// a handwheel's angle is hard to read from straight above, and from above is
// how a board is mostly seen.
var PLATE = { y: 1.57, z: 1.1, width: 2.6, depth: 0.8 }

// What a piece is made of. The subject owns the mapping to colours; this
// only says which of them a row claims (see README.md, "Colour by role").
var ROLES = ["shell", "metal", "actuator", "print"]

// Every part, with the displacement it takes at the end of its stage.
//
//   parent  the part this one sits inside, "" at the top level
//   order   place in the lesson, 1-based; 0 = drawn but never explained
//   stage   1 travels while spread goes 0 -> 1, 2 while it goes 1 -> 2
//   offset  the whole displacement at the end of that stage, relative to
//           whatever the part sits in
//   anchor  where a mark, an assembly line or a fingertip lands, local to
//           the part's own origin
//
// Where the pieces GO is not arbitrary: the rig looks from +z and above, so
// the flanges leave sideways and the stem and the handwheel straight up, and
// nothing travels toward the camera except the flat plate, which has nothing
// behind it to hide. Stage 1 lifts the outside off (the handwheel as one
// piece, the flanges off the ports); stage 2 opens what that exposed - the
// stem out of the body, the rim off its spokes.
var PARTS = [
    { id: "body", parent: "", role: "shell", order: 1, stage: 1,
      offset: { x: 0, y: 0, z: 0 },
      anchor: { x: 0, y: BODY.height, z: BODY.depth * 0.5 } },

    { id: "flange.in", parent: "", role: "metal", order: 2, stage: 1,
      offset: { x: -3.5, y: 0, z: 0 },
      anchor: { x: 0, y: 0, z: FLANGE.radius } },

    { id: "flange.out", parent: "", role: "metal", order: 3, stage: 1,
      offset: { x: 3.5, y: 0, z: 0 },
      anchor: { x: 0, y: 0, z: FLANGE.radius } },

    // Out of the body, in the second stage: the stem is what the handwheel
    // was hiding, and it rises into the gap the lifted wheel leaves.
    { id: "stem", parent: "", role: "metal", order: 4, stage: 2,
      offset: { x: 0, y: 3.2, z: 0 },
      anchor: { x: 0, y: STEM.height * 0.5, z: 0 } },

    // The sub-assembly: the handwheel leaves as a whole in stage 1 and comes
    // apart on its own in stage 2. Its children's offsets are relative to it.
    { id: "handwheel", parent: "", role: "actuator", order: 5, stage: 1,
      offset: { x: 0, y: 4.0, z: 0 },
      anchor: { x: 0, y: 0, z: WHEEL.rimRadius } },
    { id: "handwheel.rim", parent: "handwheel", role: "actuator", order: 6, stage: 2,
      offset: { x: 0, y: 1.2, z: 0 },
      anchor: { x: 0, y: WHEEL.rimHeight * 0.5, z: 0 } },
    { id: "handwheel.spokes", parent: "handwheel", role: "actuator", order: 0, stage: 2,
      offset: { x: 0, y: 0, z: 0 },
      anchor: { x: 0, y: WHEEL.spokeY + WHEEL.spokeHeight, z: 0 } },

    // The plate slides forward off the body's top rather than staying put:
    // left where it is, it reads as a label floating inside the silhouette of
    // a body that is no longer closed.
    { id: "plate", parent: "", role: "print", order: 0, stage: 1,
      offset: { x: 0, y: 0, z: 2.2 },
      anchor: { x: 0, y: 0, z: 0 } }
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

// How far a part of `stage` has travelled at `spread`: 0 before its stage
// begins, 1 once it is over, linear in between - the kernel's own rule.
function travelAt(stage, spread) {
    var s = stage === undefined || stage < 1 ? 1 : stage
    var v = spread === undefined ? 0 : spread
    var t = v - (s - 1)
    return t < 0 ? 0 : (t > 1 ? 1 : t)
}

// Displacement of a part at a given spread (0 assembled .. 2 fully apart),
// as a plain triple. Linear on purpose: easing is the animator's business.
function offsetAt(id, spread) {
    var p = partById(id)
    if (!p) return { x: 0, y: 0, z: 0 }
    var t = travelAt(p.stage, spread)
    return { x: p.offset.x * t, y: p.offset.y * t, z: p.offset.z * t }
}

// Sanity: ids unique, parents known, roles known, order dense, stages whole
// and at least 1, every offset and anchor finite. A list of problems; empty
// means fine.
function validate() {
    var problems = []
    var seen = {}
    var orders = []
    var finite = function (v) {
        return !!v && isFinite(v.x) && isFinite(v.y) && isFinite(v.z)
    }
    for (var i = 0; i < PARTS.length; ++i) {
        var p = PARTS[i]
        if (!p.id) problems.push("row " + i + " has no id")
        else if (seen[p.id]) problems.push("duplicate id " + p.id)
        seen[p.id] = true
        if (p.parent && !partById(p.parent))
            problems.push("unknown parent " + p.parent + " on " + p.id)
        if (p.parent === p.id) problems.push("cycle through " + p.id)
        if (ROLES.indexOf(p.role) < 0) problems.push("unknown role " + p.role + " on " + p.id)
        if (p.order !== Math.floor(p.order) || p.order < 0)
            problems.push("order is not a whole number on " + p.id)
        else if (p.order > 0) orders.push(p.order)
        if (p.stage !== Math.floor(p.stage) || p.stage < 1)
            problems.push("stage below 1 on " + p.id)
        if (!finite(p.offset)) problems.push("non-finite offset on " + p.id)
        if (!finite(p.anchor)) problems.push("non-finite anchor on " + p.id)
    }
    orders.sort(function (a, b) { return a - b })
    for (var k = 0; k < orders.length; ++k)
        if (orders[k] !== k + 1) { problems.push("order is not 1.." + orders.length); break }
    return problems
}
