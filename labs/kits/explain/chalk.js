// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// What a chalk explanation IS, with no idea how to paint one.
//
// A drawing is a list of strokes in its own unit space (1000 x 600, the
// proportions of a board). The renderer fits that box into whatever slate it
// has; nothing here knows about pixels, Canvas, fonts or the theme.
//
// The reason the model is separate: the interesting question about a drawing
// that draws itself is "how much of it is on the board at progress p", and
// that is arithmetic over stroke lengths - checkable by `node
// chalk.test.js` in a second, where checking it through a Canvas would mean
// reading pixels. `length()` prices every op in "ink", `total()` adds it up
// and `at()` answers the question. A pause costs ink too, so a beat in the
// middle of an explanation is a stroke that happens to draw nothing.
//
// Qt-free on purpose (no Qt types, no clock, no Math.random): the drawing a
// learner sees is a pure function of the labels and the progress, so two
// runs of the same lab draw the same board.

// The unit box every drawing here is laid out in.
var UNIT = { width: 1000, height: 600 }

// An arrow head is two strokes of this length, at this angle off the shaft.
var HEAD = 18
var HEAD_ANGLE = 0.46

// Ink per glyph of text, and ink per millisecond of pause. Both are prices,
// not measurements: they set how long a word takes to appear relative to a
// line, which is a matter of teaching rhythm.
var GLYPH = 18
var PAUSE_RATE = 0.25

// Every op name the model knows. A drawing carrying anything else is broken,
// and `validate()` says so rather than the renderer silently skipping it.
var OPS = ["line", "rect", "arrow", "text", "curve", "axes", "plot", "pause"]

function _num(v) { return typeof v === "number" && isFinite(v) }

function _txt(v) { return (v === undefined || v === null) ? "" : String(v) }

// A label the caller did not supply falls back to its own key, so a missing
// string shows up on the board as `emitter` instead of costing zero ink and
// vanishing without trace.
function _lab(labels, key) {
    var v = (labels && labels[key] !== undefined) ? String(labels[key]) : ""
    return v.length > 0 ? v : key
}

function _dist(a, b) {
    var dx = b[0] - a[0], dy = b[1] - a[1]
    return Math.sqrt(dx * dx + dy * dy)
}

// Total length of a polyline. The one measurement four ops share.
function polyLength(points) {
    var t = 0
    if (!points) return 0
    for (var i = 1; i < points.length; ++i) t += _dist(points[i - 1], points[i])
    return t
}

// The two barb roots of an arrow head; both barbs run from these to `to`.
// The renderer and `length()` both go through this, so the price of an arrow
// and the picture of one can never disagree.
function arrowHeads(from, to, head) {
    var h = (head === undefined) ? HEAD : head
    var back = Math.atan2(from[1] - to[1], from[0] - to[0])
    return [[to[0] + h * Math.cos(back - HEAD_ANGLE),
             to[1] + h * Math.sin(back - HEAD_ANGLE)],
            [to[0] + h * Math.cos(back + HEAD_ANGLE),
             to[1] + h * Math.sin(back + HEAD_ANGLE)]]
}

// A rect as the closed path a hand draws it as: round the four corners and
// back to the start, so "half of a rect" means half of its perimeter.
function rectPath(op) {
    var x = op.at[0], y = op.at[1], w = op.size[0], h = op.size[1]
    return [[x, y], [x + w, y], [x + w, y + h], [x, y + h], [x, y]]
}

// A plot's points arrive in axes units (0..1 of the box, y up) and come back
// in drawing units (y down) - the same mapping the axes op implies.
function plotPoints(op) {
    var x = op.at[0], y = op.at[1], w = op.size[0], h = op.size[1]
    var ps = op.points || []
    var out = []
    for (var i = 0; i < ps.length; ++i)
        out.push([x + ps[i][0] * w, y + h - ps[i][1] * h])
    return out
}

// `axes` is the one composite op: two arrows out of the origin corner plus
// the two labels, in the order a hand draws them. Expanding it here is what
// lets `length()` price it and `cut()` draw a half-finished pair of axes
// without either of them knowing what axes are.
function subOps(op) {
    if (!op || op.op !== "axes") return null
    var x = op.at[0], y = op.at[1], w = op.size[0], h = op.size[1]
    var origin = [x, y + h]
    return [{ op: "arrow", from: origin, to: [x + w, y + h] },
            { op: "arrow", from: origin, to: [x, y] },
            { op: "text", at: [x + w * 0.45, y + h + 38],
              text: _txt(op.xLabel), size: 30 },
            { op: "text", at: [x + 14, y - 16],
              text: _txt(op.yLabel), size: 30 }]
}

/* Ink cost of one op: geometric stroke length for strokes, a per-glyph price
   for text, a per-millisecond price for a pause. Unknown ops cost nothing. */
function length(op) {
    if (!op || !op.op) return 0
    if (op.op === "line") return _dist(op.from, op.to)
    if (op.op === "rect") return polyLength(rectPath(op))
    if (op.op === "arrow") return _dist(op.from, op.to) + 2 * HEAD
    if (op.op === "text") return GLYPH * _txt(op.text).length
    if (op.op === "curve") return polyLength(op.points)
    if (op.op === "plot") return polyLength(plotPoints(op))
    if (op.op === "pause") return Math.max(0, _num(op.ms) ? op.ms : 0) * PAUSE_RATE
    if (op.op === "axes") {
        var subs = subOps(op), t = 0
        for (var i = 0; i < subs.length; ++i) t += length(subs[i])
        return t
    }
    return 0
}

/* How much ink the whole drawing costs. */
function total(drawing) {
    var ops = (drawing && drawing.ops) ? drawing.ops : []
    var t = 0
    for (var i = 0; i < ops.length; ++i) t += length(ops[i])
    return t
}

/* What is on the board at `progress` (clamped to 0..1): every op the cursor
   has passed with `frac: 1`, the one it is inside with `frac` in (0, 1), and
   nothing after it. A pause yields nothing to draw but still holds the
   cursor, which is how a beat happens. */
function at(drawing, progress) {
    var ops = (drawing && drawing.ops) ? drawing.ops : []
    var p = _num(progress) ? Math.max(0, Math.min(1, progress)) : 0
    var cursor = total(drawing) * p
    var out = []
    var acc = 0
    for (var i = 0; i < ops.length; ++i) {
        var L = length(ops[i])
        if (L <= 0) {
            // a free op (an empty text) is either behind the cursor or not
            // reached - never "in progress", which would divide by zero
            if (cursor > acc) { out.push({ op: ops[i], frac: 1 }); continue }
            break
        }
        if (acc + L <= cursor) out.push({ op: ops[i], frac: 1 })
        else if (acc < cursor) { out.push({ op: ops[i], frac: (cursor - acc) / L }); break }
        else break
        acc += L
    }
    return out
}

/* One op, part-drawn, as primitive ops only: a composite (`axes`) is cut
   into the sub-strokes its `frac` reaches, a primitive comes back as itself.
   The renderer calls this and never has to know which ops are composite. */
function cut(op, frac) {
    var f = _num(frac) ? Math.max(0, Math.min(1, frac)) : 0
    var subs = subOps(op)
    if (!subs) return [{ op: op, frac: f }]
    var t = 0, i
    for (i = 0; i < subs.length; ++i) t += length(subs[i])
    var ink = t * f
    var out = [], acc = 0
    for (i = 0; i < subs.length; ++i) {
        var L = length(subs[i])
        if (L <= 0) continue
        if (acc + L <= ink) out.push({ op: subs[i], frac: 1 })
        else if (acc < ink) { out.push({ op: subs[i], frac: (ink - acc) / L }); break }
        else break
        acc += L
    }
    return out
}

// Every point an op occupies, for the box check below.
function _extent(op) {
    if (op.op === "line" || op.op === "arrow") return [op.from, op.to]
    if (op.op === "rect" || op.op === "axes") return rectPath(op)
    if (op.op === "text") return [op.at]
    if (op.op === "curve") return op.points || []
    if (op.op === "plot") return rectPath(op).concat(plotPoints(op))
    return []
}

function _checkOp(d, op, where, problems) {
    if (!op || OPS.indexOf(op.op) < 0) {
        problems.push(where + ": unknown op " + (op ? op.op : op))
        return
    }
    if (op.op === "pause") {
        if (!_num(op.ms) || op.ms < 0) problems.push(where + ": bad pause ms")
        return
    }
    if (op.op === "text" && _txt(op.text).length === 0)
        problems.push(where + ": empty text draws nothing")
    if (op.op === "plot") {
        var ps = op.points || []
        if (ps.length < 2) problems.push(where + ": a plot needs two points")
        for (var k = 0; k < ps.length; ++k)
            if (!(ps[k][0] >= 0 && ps[k][0] <= 1 && ps[k][1] >= 0 && ps[k][1] <= 1))
                problems.push(where + ": point " + k + " is not in axes units")
    }
    var pts = _extent(op)
    for (var j = 0; j < pts.length; ++j) {
        var x = pts[j][0], y = pts[j][1]
        if (!_num(x) || !_num(y)) { problems.push(where + ": non-finite point"); continue }
        if (x < 0 || x > d.width || y < 0 || y > d.height)
            problems.push(where + ": " + x.toFixed(1) + "," + y.toFixed(1)
                          + " is outside the unit box")
    }
    if (op.op === "axes") {
        var subs = subOps(op)
        for (var m = 0; m < subs.length; ++m)
            _checkOp(d, subs[m], where + "." + m, problems)
    }
}

/* Sanity of a drawing: known ops, finite coordinates inside the unit box,
   plot points in axes units. Returns a list of problems; empty means fine. */
function validate(drawing) {
    var problems = []
    if (!drawing || !_num(drawing.width) || !_num(drawing.height)
        || drawing.width <= 0 || drawing.height <= 0) {
        problems.push("drawing has no unit box")
        return problems
    }
    var ops = drawing.ops || []
    if (ops.length === 0) problems.push("drawing has no ops")
    for (var i = 0; i < ops.length; ++i) _checkOp(drawing, ops[i], "op " + i, problems)
    return problems
}

// --- the two drawings ------------------------------------------------------
// These are CONTENT, not mechanism: everything above is a chalkboard for any
// subject, and these two are what the transistor lesson of issue #269 needs.
// Geometry, like the anatomy's, is teaching geometry - a real base layer is
// microns thin and would be a hairline here.

// The cross-section, as three stacked slabs: a wide N collector at the
// bottom (it IS the substrate), a thin P base over it, a small N emitter
// island on top. Same bottom-up order the anatomy teaches the die in.
var SECTION = {
    collector: { at: [300, 320], size: [400, 120] },
    base:      { at: [300, 260], size: [400,  60] },
    emitter:   { at: [420, 192], size: [170,  68] }
}

/* The N-P-N cross-section. `labels` supplies `n`, `p`, `collector`, `base`,
   `emitter`, `ib`, `ic`; a missing key falls back to its own name. */
function transistorSection(labels) {
    var c = SECTION.collector, b = SECTION.base, e = SECTION.emitter
    // The base arrow runs along the middle of the base slab and stops inside
    // it; the collector arrow clears the stack top and bottom by a hair, so it
    // reads as current passing THROUGH rather than as a line pinned to it.
    var mid = b.at[1] + b.size[1] / 2
    var icX = 540
    var ops = [
        // the stack, bottom-up
        { op: "rect", at: c.at, size: c.size },
        { op: "rect", at: b.at, size: b.size },
        { op: "rect", at: e.at, size: e.size },
        // the doping, one letter beside each slab
        { op: "text", at: [c.at[0] + c.size[0] + 28, c.at[1] + 74],
          text: _lab(labels, "n"), size: 38 },
        { op: "text", at: [b.at[0] + b.size[0] + 28, b.at[1] + 44],
          text: _lab(labels, "p"), size: 38 },
        { op: "text", at: [e.at[0] + e.size[0] + 28, e.at[1] + 48],
          text: _lab(labels, "n"), size: 38 },
        // what each slab is called, on the side the legs come out of
        { op: "text", at: [60, c.at[1] + 74], text: _lab(labels, "collector"), size: 30 },
        { op: "text", at: [60, b.at[1] + 42], text: _lab(labels, "base"), size: 30 },
        { op: "text", at: [60, e.at[1] + 44], text: _lab(labels, "emitter"), size: 30 },
        // Structure first, then what moves - the beat between the two is the
        // difference between "this is what it is made of" and "this is what
        // it does", and a drawing that runs them together teaches neither.
        { op: "pause", ms: 700 },
        // a small current in at the base
        { op: "arrow", from: [165, mid], to: [b.at[0] + 45, mid] },
        // well clear of the slab's top edge: the label is longer than the gap
        // between the arrow and the stack, so it has to sit above both
        { op: "text", at: [200, mid - 48], text: _lab(labels, "ib"), size: 26 },
        // a large one straight up through the whole stack
        { op: "arrow", from: [icX, c.at[1] + c.size[1] + 32], to: [icX, e.at[1] - 28] },
        { op: "text", at: [icX + 28, e.at[1] - 10], text: _lab(labels, "ic"), size: 26 }
    ]
    return { width: UNIT.width, height: UNIT.height, ops: ops }
}

// The bias point electronics-101 puts on the board: 0.80 mA into the base
// and 9.8 mA through the lamp, so beta reads about 12 there.
var WORK = { ib: 0.80, ic: 9.8 }
// Where that point sits on the x axis - it has to be early, because the
// interesting part of the curve is what happens AFTER it.
var WORK_X = 0.30
// Base current at which the lamp cannot pass any more: the knee.
var KNEE_IB = 1.25

/* Axes, the `Ic = beta * Ib` line up to its saturation knee, a marker on the
   working point and the gain as a word. `labels` supplies `ib`, `ic`,
   `beta`. */
function gainGraph(beta, labels) {
    var b = (_num(beta) && beta > 0) ? beta : WORK.ic / WORK.ib
    var ibMax = WORK.ib / WORK_X
    var kneeIb = Math.min(KNEE_IB, ibMax)
    var satIc = b * kneeIb
    // Headroom above the flat top, and enough of it that the MEASURED
    // working point still fits when the drawn beta is small.
    var icMax = Math.max(satIc * 1.25, WORK.ic * 1.15)
    var box = [180, 90], size = [660, 400]
    var kx = kneeIb / ibMax, ky = satIc / icMax
    var wy = WORK.ic / icMax
    var px = box[0] + WORK_X * size[0]
    var py = box[1] + size[1] - wy * size[1]
    var m = 18
    return { width: UNIT.width, height: UNIT.height, ops: [
        { op: "axes", at: box, size: size,
          xLabel: _lab(labels, "ib"), yLabel: _lab(labels, "ic") },
        { op: "plot", at: box, size: size, points: [[0, 0], [kx, ky], [1, ky]] },
        { op: "pause", ms: 400 },
        // The marker sits on the MEASURED point, the line on the drawn beta -
        // so with a rounded beta the two miss each other by a hair. That gap
        // is the rounding, and it is honest; do not snap the marker to the line.
        { op: "rect", at: [px - m / 2, py - m / 2], size: [m, m] },
        { op: "text", at: [365, 362], text: _lab(labels, "beta"), size: 32 }
    ] }
}
