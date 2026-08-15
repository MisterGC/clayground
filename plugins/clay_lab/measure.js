// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The tape measure's arithmetic: a chain of points, the length of each leg,
// the angle at each corner, the running total - and the text of all three.
//
// Pure JS, and separate from the overlay that draws it, for the reason every
// geometry bug has: a length that lives inside a paint call can only be
// checked by looking at a picture. Here `node measure.test.js` checks the
// 3-4-5 triangle and its 36.87 degrees, and the overlay is left with nothing
// to get wrong but pixels.
//
// The points are anything with x/y/z - Qt.vector3d in the lab, plain objects
// in the suite. Nothing here touches Qt.
//

// The formatter arrives as an argument rather than being read off LabLang,
// which is what keeps this file engine-free: the lab passes
// `(d) => LabLang.qty(d, unit)`, the suite passes whatever it wants to assert.
function _identity(v) { return String(v) }

function _sub(a, b) { return { x: a.x - b.x, y: (a.y || 0) - (b.y || 0), z: a.z - b.z } }
function _len(v) { return Math.hypot(v.x, v.y, v.z) }

/*
    The straight-line distance between two points, in world units.
*/
function distance(a, b) { return _len(_sub(a, b)) }

/*
    The midpoint of a leg - where its label sits.
*/
function midpoint(a, b) {
    return { x: (a.x + b.x) / 2,
             y: ((a.y || 0) + (b.y || 0)) / 2,
             z: (a.z + b.z) / 2 }
}

/*
    The legs of the chain: [{ i, a, b, mid, length }], one per pair.
*/
function segments(points) {
    var out = []
    if (!points) return out
    for (var i = 1; i < points.length; ++i) {
        var a = points[i - 1], b = points[i]
        out.push({ i: i - 1, a: a, b: b, mid: midpoint(a, b), length: distance(a, b) })
    }
    return out
}

/*
    Total length walked along the chain.
*/
function total(points) {
    var sum = 0
    var segs = segments(points)
    for (var i = 0; i < segs.length; ++i) sum += segs[i].length
    return sum
}

/*
    The angle at interior vertex `i`, in degrees: the corner BETWEEN the two
    legs that meet there, so a straight line reads 180 and a fold back on
    itself reads 0. Null where there is no corner - the ends of the chain, and
    a doubled point, which has no direction to measure from.
*/
function angleAt(points, i) {
    if (!points || i <= 0 || i >= points.length - 1) return null
    var u = _sub(points[i - 1], points[i])
    var v = _sub(points[i + 1], points[i])
    var lu = _len(u), lv = _len(v)
    if (lu < 1e-9 || lv < 1e-9) return null
    var c = (u.x * v.x + u.y * v.y + u.z * v.z) / (lu * lv)
    // acos is defined on [-1, 1] and floating point is not: two legs exactly
    // in line give 1.0000000000000002, which comes back NaN without this.
    if (c > 1) c = 1
    if (c < -1) c = -1
    return Math.acos(c) * 180 / Math.PI
}

/*
    Every corner that has an angle: [{ i, at, deg }].
*/
function vertices(points) {
    var out = []
    if (!points) return out
    for (var i = 1; i < points.length - 1; ++i) {
        var d = angleAt(points, i)
        if (d !== null) out.push({ i: i, at: points[i], deg: d })
    }
    return out
}

/*
    "36.9°" - one decimal, in the caller's decimal notation. One decimal
    because that is the precision a click on a ground plane earns: the tenth
    of a degree moves with the pixel, the hundredth is noise.
*/
function angleText(deg, sep) {
    var s = Number(deg).toFixed(1)
    if (Number(s) === 0) s = (0).toFixed(1)
    if (sep && sep !== ".") s = s.replace(".", sep)
    return s + "°"
}

/*
    The whole readout in one object, ready for a Repeater:

        { segments: [{ i, a, b, mid, length, text }],
          vertices: [{ i, at, deg, text }],
          total, totalAt, totalText, closed }

    `fmt` formats a length; `sep` is the decimal separator for the angles.
    `totalAt` is the last point - where the running total is written - and is
    null until there are two legs to add up, because a total that repeats the
    one length above it is just a second label saying the same thing.
*/
function readout(points, fmt, sep) {
    var f = fmt || _identity
    var segs = segments(points)
    var out = { segments: [], vertices: [], total: 0, totalAt: null,
                totalText: "", count: points ? points.length : 0 }
    for (var i = 0; i < segs.length; ++i) {
        var s = segs[i]
        out.total += s.length
        out.segments.push({ i: s.i, a: s.a, b: s.b, mid: s.mid,
                            length: s.length, text: f(s.length) })
    }
    var vs = vertices(points)
    for (var j = 0; j < vs.length; ++j)
        out.vertices.push({ i: vs[j].i, at: vs[j].at, deg: vs[j].deg,
                            text: angleText(vs[j].deg, sep) })
    if (segs.length >= 2) {
        out.totalAt = points[points.length - 1]
        out.totalText = f(out.total)
    }
    return out
}
