// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The pen and the price list behind the sketched look of Clayground.Canvas
// items: where a stroke's samples sit, how far a hand pushes each one off the
// straight line, where an arrow's barbs are, where a ray leaves a box, and how
// one progress number in [0, 1] is split over parts that are drawn one after
// another.
//
// Deterministic on purpose: no Math.random, no clock, no Qt type. The same
// seed and the same vertices give the same line in a render, in a test and on
// another machine. Every rule here is arithmetic, so `node sketch.test.js`
// checks it in a second with no engine running.
//

var LOOKS = ["none", "chalk", "marker"]
var STEP = 14            // sample spacing along a stroke, px (a hand's wobble is a pixel thing)
var HEAD_ANGLE = 0.46    // rad, each barb off the shaft
var GLYPH_INK = 0.6      // ink of one glyph in font-size units (a glyph is ~0.6 em wide)

// --- the pen ----------------------------------------------------------------
//
// `wobble` and `jag` are amplitudes as multiples of strokeWidth: wobble is the
// slow drift of a hand, jag the per-sample roughness of chalk. `grain` asks for
// a second, wider, fainter pass (chalk dust); `alpha` is the main pass.

var PEN = {
    chalk:  { name: "chalk",  wobble: 0.35, jag: 0.30, alpha: 0.92, grain: true,  grainAlpha: 0.22, grainWidth: 1.8 },
    marker: { name: "marker", wobble: 0.30, jag: 0.05, alpha: 1.0,  grain: false, grainAlpha: 0,    grainWidth: 1 },
    none:   { name: "none",   wobble: 0,    jag: 0,    alpha: 1,    grain: false, grainAlpha: 0,    grainWidth: 1 }
}

function isSketch(name) { return name === "chalk" || name === "marker" }

// Looked up by name rather than by index into PEN, so a property holding
// "constructor" or "toString" is an unknown look and not a function.
function penOf(name) { return isSketch(name) ? PEN[name] : PEN.none }

// A fresh object per call: an item that binds its look to a property must not
// be able to edit the table every other item reads.
function look(name) {
    var p = penOf(name)
    return { name: p.name, wobble: p.wobble, jag: p.jag, alpha: p.alpha,
             grain: p.grain, grainAlpha: p.grainAlpha, grainWidth: p.grainWidth }
}

// --- noise ------------------------------------------------------------------

// Integer hash to [-1, 1). Stateless, so sample k can be drawn without having
// drawn k - 1: a trimmed stroke must not depend on where the trim started.
function hash(k, seed) {
    var h = (k | 0) ^ Math.imul((seed | 0) ^ 0x9E3779B9, 0x85EBCA6B)
    h = Math.imul(h ^ (h >>> 16), 0x21F0AAAD)
    h = Math.imul(h ^ (h >>> 15), 0x735A2D97)
    h = h ^ (h >>> 15)
    return (h >>> 0) / 2147483648 - 1
}

// Value noise over the sample index: a hashed lattice every LATTICE samples,
// cosine-interpolated in between. A hand drifts, it does not jump, so the slow
// part of the displacement has to be continuous in k.
var LATTICE = 4

function smooth(k, seed) {
    var u = k / LATTICE
    var i = Math.floor(u)
    var t = u - i
    var a = hash(i, seed)
    var b = hash(i + 1, seed)
    var f = (1 - Math.cos(Math.PI * t)) / 2
    return a + (b - a) * f
}

// The sideways displacement of sample k as a multiple of strokeWidth. The jag
// pass gets a different seed (+ 7) than the wobble pass, otherwise the rough
// part would ride exactly on the drift and chalk would look like a wide marker.
function offset(k, seed, look) {
    var p = (look && typeof look === "object") ? look : penOf(look)
    return p.wobble * smooth(k, seed) + p.jag * hash(k, seed + 7)
}

// --- polylines ---------------------------------------------------------------

function dist(a, b) {
    var dx = b.x - a.x, dy = b.y - a.y
    return Math.sqrt(dx * dx + dy * dy)
}

function polyLength(points) {
    if (!points || points.length < 2) return 0
    var sum = 0
    for (var i = 0; i < points.length - 1; ++i) sum += dist(points[i], points[i + 1])
    return sum
}

// How many pieces a segment of `length` is cut into at spacing `step`. At
// least one, so a segment shorter than a step is still a segment and not a gap.
function pieces(length, step) {
    if (!(step > 0)) return 1
    return Math.max(1, Math.ceil(length / step))
}

// A polyline resampled for sketching: every original vertex, plus the interior
// points of each segment. (nx, ny) is the unit LEFT normal of the segment the
// sample lies on, which is the direction the pen is later pushed along; a
// vertex carries its outgoing segment's normal, the last vertex the incoming
// one. A zero-length segment contributes no interior points and keeps the last
// normal, so a repeated vertex does not blank the pen for the samples after it.
function sample(points, step) {
    var out = []
    if (!points || !points.length) return out
    var n = points.length
    if (n === 1) {
        out.push({ x: points[0].x, y: points[0].y, nx: 0, ny: 0, vertex: true })
        return out
    }
    var nx = 0, ny = 0
    for (var i = 0; i < n - 1; ++i) {
        var a = points[i], b = points[i + 1]
        var dx = b.x - a.x, dy = b.y - a.y
        var len = Math.sqrt(dx * dx + dy * dy)
        if (len > 0) { nx = -dy / len; ny = dx / len }
        out.push({ x: a.x, y: a.y, nx: nx, ny: ny, vertex: true })
        var cnt = pieces(len, step)
        for (var j = 1; j < cnt; ++j) {
            var t = j / cnt
            out.push({ x: a.x + dx * t, y: a.y + dy * t, nx: nx, ny: ny, vertex: false })
        }
    }
    var last = points[n - 1]
    out.push({ x: last.x, y: last.y, nx: nx, ny: ny, vertex: true })
    return out
}

// The pixel position of sample k under a look. A vertex is never moved: a
// stroke starts and ends exactly where it was asked to, and two strokes that
// share a corner keep sharing it.
function displaced(s, k, seed, look, strokeWidth) {
    if (s.vertex) return { x: s.x, y: s.y }
    var w = Number(strokeWidth)
    if (!isFinite(w)) w = 0
    var o = offset(k, seed, look) * w
    return { x: s.x + s.nx * o, y: s.y + s.ny * o }
}

// --- arrows ------------------------------------------------------------------

// Tip at `to`, the two barb roots `size` away from it, HEAD_ANGLE either side
// of the direction back towards `from`. A head on a zero-length shaft has no
// direction to point along, so its barbs collapse onto the tip rather than
// becoming NaN and taking the whole ShapePath with them.
function arrowHead(from, to, size) {
    var dx = from.x - to.x, dy = from.y - to.y
    var len = Math.sqrt(dx * dx + dy * dy)
    var tip = { x: to.x, y: to.y }
    if (!(len > 0)) return { tip: tip, left: { x: tip.x, y: tip.y }, right: { x: tip.x, y: tip.y } }
    var a = Math.atan2(dy, dx)
    return {
        tip: tip,
        left: { x: tip.x + size * Math.cos(a + HEAD_ANGLE), y: tip.y + size * Math.sin(a + HEAD_ANGLE) },
        right: { x: tip.x + size * Math.cos(a - HEAD_ANGLE), y: tip.y + size * Math.sin(a - HEAD_ANGLE) }
    }
}

// --- progress ----------------------------------------------------------------

function clamp01(v) {
    if (typeof v !== "number" || !isFinite(v)) return 0
    return v < 0 ? 0 : (v > 1 ? 1 : v)
}

// The ink split of parts drawn one after another: `lengths` are their prices in
// one unit, the returned fraction per part is what of it is drawn at
// `progress`. One number in, one number per part out, so an item can hand each
// part a trim fraction without knowing what the others cost.
//
// A part priced 0 has no inside to be in the middle of - it is drawn whole the
// moment the cursor reaches it, never "in progress" - and a run that costs
// nothing at all is either not started or entirely done. "Reaches", not
// "passes": at progress 1 the cursor sits exactly on a free last part, and a
// finished drawing must not be missing its last word.
function split(lengths, progress) {
    var out = []
    if (!lengths || !lengths.length) return out
    var p = clamp01(progress)
    var i, total = 0
    for (i = 0; i < lengths.length; ++i) {
        var v = Number(lengths[i])
        total += (isFinite(v) && v > 0) ? v : 0
    }
    if (!(total > 0)) {
        for (i = 0; i < lengths.length; ++i) out.push(p > 0 ? 1 : 0)
        return out
    }
    var cursor = p * total
    var acc = 0
    for (i = 0; i < lengths.length; ++i) {
        var L = Number(lengths[i])
        if (!(isFinite(L) && L > 0)) { out.push(cursor > 0 && cursor >= acc ? 1 : 0); continue }
        if (cursor >= acc + L) out.push(1)
        else if (cursor <= acc) out.push(0)
        else out.push((cursor - acc) / L)
        acc += L
    }
    return out
}

// Whole characters, so a line writes itself letter by letter instead of
// growing a sliver of the next glyph.
function glyphs(text, progress) {
    if (!text || !text.length) return 0
    return Math.ceil(clamp01(progress) * text.length)
}

// What a text line costs in the same unit as a stroke's length, so a label can
// take its share of a progress run next to lines and arrows.
function textInk(text, fontSize) {
    if (!text || !text.length) return 0
    return GLYPH_INK * fontSize * text.length
}

// --- boxes -------------------------------------------------------------------

// Where the ray from the centre of an axis-aligned box towards (tx, ty) leaves
// it. The centre itself for a target inside the box or on it, and for a box
// with no extent - a connector that cannot find an edge meets the centre, which
// is the behaviour it had before edges existed.
function boxEdge(cx, cy, hw, hh, tx, ty) {
    var c = { x: cx, y: cy }
    if (!(hw > 0) || !(hh > 0)) return c
    var dx = tx - cx, dy = ty - cy
    if (!isFinite(dx) || !isFinite(dy)) return c
    if (Math.abs(dx) <= hw && Math.abs(dy) <= hh) return c
    var t = Infinity
    if (dx !== 0) t = Math.min(t, hw / Math.abs(dx))
    if (dy !== 0) t = Math.min(t, hh / Math.abs(dy))
    if (!isFinite(t)) return c
    return { x: cx + dx * t, y: cy + dy * t }
}
