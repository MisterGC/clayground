// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Layout arithmetic for the schematic panel.
//
// The small schematic is a picture and nothing else: symbols where the parts
// are, lines where the wires are, not one word anywhere, because at 250 by 176
// pixels there is nowhere to put a word. Maximised, the same drawing finally
// has room for the thing that makes a schematic a schematic - every part named
// and rated beside its own symbol. That one difference is what this file is
// for.
//
// Placing those names is the entire problem. A label is not a decoration that
// may land anywhere: a designator sitting on a wire reads as a node name, one
// sitting on another label reads as neither, and one half off the panel reads
// as nothing at all. So the question answered here is "where does this text
// go", and it is answered by trying the four sides of a symbol in a fixed
// order and taking the first that is free - free of every symbol, free of
// every label already placed, and inside the panel.
//
// Two consequences worth stating before the code. Order decides ties: the
// anchor earlier in the list wins the contested spot, so the same board
// letters the same way on every repaint and the diagram does not shuffle while
// you are reading it. And a label that finds no free side is reported rather
// than hidden - `placed: false` hands the choice back to the caller, draw it
// anyway or drop it, because only the caller knows whether that particular
// name is the one the reader came for.
//
// Geometry and arithmetic only - no Qt types, no colours, no words of its own -
// so plan.test.js can check it under node in a second.
.pragma library

// --- tunables ---------------------------------------------------------------

// The smallest source-space span a fit will divide by. Two parts standing on
// the same peg have a span of zero, and one part has no span at all; without a
// floor those cases would ask for infinite magnification. A little over one
// cell is the honest answer to "how big is a board with nothing spread out on
// it": big enough to see, not so big that a single resistor fills the panel.
var MIN_SPAN = 1.2

// The smallest box a fit will work with, in pixels. A panel narrower than its
// own margins is a transient during a resize, not a layout to solve; clamping
// keeps the scale positive and finite until the real size arrives.
var MIN_ROOM = 1

// Pixels between a symbol's edge and its label's edge, when the caller does
// not say.
var DEFAULT_GAP = 4

// The order the sides are tried in. Below first because a designator under its
// part is where a schematic puts it and where the eye looks for it; above
// second because that is the same relationship mirrored; the two flanks last,
// because a name beside a part competes with the part's own leads.
var DEFAULT_SIDES = ["below", "above", "right", "left"]

// Pixels per source cell below which lettering is not worth attempting. Two
// lines of text are around 24 pixels tall, and below this scale that block is
// taller than the space between neighbouring parts, so every label would land
// on something and the answer would be a page of `placed: false`.
var MIN_SCALE = 34

var EPS = 1e-6

// --- rectangles -------------------------------------------------------------

// Two axis-aligned rectangles, {x, y, w, h} with x,y the top-left corner.
// Touching is not overlapping: a label whose edge sits exactly on a symbol's
// edge is beside it, which is precisely what a gap of zero is asking for.
// An empty rectangle covers nothing either - a part with no reading to show
// has a label block of no size, and it must not fence off space it will not
// draw in.
function overlaps(a, b) {
    if (!a || !b) return false
    if (!(a.w > 0) || !(a.h > 0) || !(b.w > 0) || !(b.h > 0)) return false
    return a.x < b.x + b.w - EPS && b.x < a.x + a.w - EPS
        && a.y < b.y + b.h - EPS && b.y < a.y + a.h - EPS
}

// Whether a rectangle hits anything in a list. Separate from overlaps because
// every rule in placeLabels is a list question, and answering it in one place
// keeps the rules readable as rules.
function collides(rect, rects) {
    if (!rect || !rects) return false
    for (var i = 0; i < rects.length; ++i)
        if (overlaps(rect, rects[i])) return true
    return false
}

// --- fitting ----------------------------------------------------------------

// Maps a set of source-space points into a pixel box, uniformly.
//
//   pts: [{x, y}]  - board cells, not pixels
//   box: {w, h}    - the target in pixels
//   pad: number    - pixels kept free on every side
//
// Returns {s, ox, oy, cx, cy}, to be read as px = ox + (x - cx) * s.
//
// Uniform on purpose: a scale that stretched one axis would draw a board that
// was never built. The fit is over the POINTS, not over the whole pegboard,
// because an empty board would otherwise squeeze the drawing into a corner of
// its own emptiness.
function fitBox(pts, box, pad) {
    var b = box || {}
    var bw = b.w > 0 ? b.w : 0
    var bh = b.h > 0 ? b.h : 0
    var p = pad > 0 ? pad : 0
    var room = { w: Math.max(MIN_ROOM, bw - 2 * p),
                 h: Math.max(MIN_ROOM, bh - 2 * p) }
    var flat = { s: 1, ox: bw / 2, oy: bh / 2, cx: 0, cy: 0 }
    if (!pts || !pts.length) return flat

    var x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity
    for (var i = 0; i < pts.length; ++i) {
        var q = pts[i]
        if (!q || !isFinite(q.x) || !isFinite(q.y)) continue
        if (q.x < x0) x0 = q.x
        if (q.x > x1) x1 = q.x
        if (q.y < y0) y0 = q.y
        if (q.y > y1) y1 = q.y
    }
    if (x0 > x1) return flat

    // Flooring the span can only ever make the scale smaller, so a fit stays a
    // fit: whatever the floor does to a degenerate board, the points still
    // land inside the padded box.
    var spanX = Math.max(MIN_SPAN, x1 - x0)
    var spanY = Math.max(MIN_SPAN, y1 - y0)
    return { s: Math.min(room.w / spanX, room.h / spanY),
             ox: bw / 2, oy: bh / 2,
             cx: (x0 + x1) / 2, cy: (y0 + y1) / 2 }
}

// One place to ask whether the diagram is big enough to letter, so the answer
// is not a magic number repeated at three call sites.
function readable(s, minScale) {
    var m = (minScale === undefined || minScale === null) ? MIN_SCALE : minScale
    return isFinite(s) && s >= m
}

// --- text -------------------------------------------------------------------

// The pixel size of a block of lines, given a monospace-ish cell. Deliberately
// arithmetic rather than measurement: the caller has a real font metric and
// may pass its own charW, but layout must be decidable without a paint pass.
function textBox(lines, charW, lineH) {
    if (!lines || !lines.length) return { w: 0, h: 0 }
    var cw = charW > 0 ? charW : 0
    var lh = lineH > 0 ? lineH : 0
    var widest = 0
    for (var i = 0; i < lines.length; ++i) {
        var t = (lines[i] === undefined || lines[i] === null) ? "" : String(lines[i])
        if (t.length > widest) widest = t.length
    }
    return { w: widest * cw, h: lines.length * lh }
}

// --- labels -----------------------------------------------------------------

// The box a symbol occupies, from its centre and size.
function _symbolRect(a) {
    var w = a.w > 0 ? a.w : 0
    var h = a.h > 0 ? a.h : 0
    return { x: a.x - w / 2, y: a.y - h / 2, w: w, h: h }
}

// Where a label sits if it takes a given side, before anything is checked.
// Centred on the symbol along the free axis, because a name that is centred on
// its part is unambiguous even when it is closer to a neighbour.
function _candidate(a, side, gap) {
    var hw = (a.w > 0 ? a.w : 0) / 2
    var hh = (a.h > 0 ? a.h : 0) / 2
    var lw = a.lw > 0 ? a.lw : 0
    var lh = a.lh > 0 ? a.lh : 0
    if (side === "above") return { x: a.x - lw / 2, y: a.y - hh - gap - lh, w: lw, h: lh }
    if (side === "right") return { x: a.x + hw + gap, y: a.y - lh / 2, w: lw, h: lh }
    if (side === "left") return { x: a.x - hw - gap - lw, y: a.y - lh / 2, w: lw, h: lh }
    return { x: a.x - lw / 2, y: a.y + hh + gap, w: lw, h: lh }
}

// Slides a candidate along the axis that does NOT carry its side, so a part
// near the panel edge keeps its label below it rather than losing the side
// altogether. Sliding across the side's own axis would turn "below" into a
// lie, so that direction is left to fail the inside test instead.
function _slideIn(r, box, side) {
    if (!box) return r
    if (side === "right" || side === "left")
        r.y = Math.max(0, Math.min((box.h > 0 ? box.h : 0) - r.h, r.y))
    else
        r.x = Math.max(0, Math.min((box.w > 0 ? box.w : 0) - r.w, r.x))
    return r
}

function _inside(r, box) {
    if (!box) return true
    return r.x >= -EPS && r.y >= -EPS
        && r.x + r.w <= (box.w > 0 ? box.w : 0) + EPS
        && r.y + r.h <= (box.h > 0 ? box.h : 0) + EPS
}

// Where every label goes.
//
//   anchors: [{ id, x, y, w, h, lw, lh }]
//       x, y   - the symbol's CENTRE in pixels
//       w, h   - the symbol's own size, the box a label must keep off
//       lw, lh - the label block's size
//   opts: { gap, box: {w, h}, sides, avoid }
//       gap    - pixels between symbol edge and label edge
//       box    - the panel; a label must fit inside it
//       sides  - candidate sides, in preference order
//       avoid  - extra rectangles no label may cover (wires, readouts, the
//                panel's own chrome). Optional, and empty by default, because
//                the rules below are about parts and names; anything else the
//                drawing owns is the caller's to declare.
//
// Returns [{ id, x, y, w, h, side, placed }], x,y the label block's TOP-LEFT.
// The order of the result matches the order of the anchors.
//
// The rules, in the order they matter:
//   1. no label covers ANY symbol, its own included
//   2. no label covers a label already placed
//   3. no label leaves the box
//   4. earlier anchors win contested spots
//
// A label that fails everywhere is still given its first-choice position, so
// the caller can draw it deliberately rather than compute a fallback twice.
function placeLabels(anchors, opts) {
    var out = []
    if (!anchors || !anchors.length) return out
    var o = opts || {}
    var gap = (o.gap === undefined || o.gap === null) ? DEFAULT_GAP : o.gap
    var box = o.box || null
    var sides = (o.sides && o.sides.length) ? o.sides : DEFAULT_SIDES

    // Every symbol is an obstacle from the first label onwards, not just the
    // ones already visited: a name that dodged part four only to land on part
    // five would have to be moved again, and moving it again is what makes a
    // layout depend on the order it was walked in.
    var symbols = []
    for (var i = 0; i < anchors.length; ++i) symbols.push(_symbolRect(anchors[i]))
    var extra = o.avoid || []
    var taken = []

    for (i = 0; i < anchors.length; ++i) {
        var a = anchors[i]
        var first = null
        var chosen = null
        for (var k = 0; k < sides.length; ++k) {
            var side = sides[k]
            var r = _slideIn(_candidate(a, side, gap), box, side)
            if (!first) first = { r: r, side: side }
            if (!_inside(r, box)) continue
            if (collides(r, symbols)) continue
            if (collides(r, taken)) continue
            if (collides(r, extra)) continue
            chosen = { r: r, side: side }
            break
        }
        var use = chosen || first
        out.push({ id: a.id, x: use.r.x, y: use.r.y, w: use.r.w, h: use.r.h,
                   side: use.side, placed: !!chosen })
        // Only a placed label reserves its space. An unplaced one is a
        // suggestion, and a suggestion that pushed the next label aside would
        // cost real estate to a name that may never be drawn.
        if (chosen) taken.push(use.r)
    }
    return out
}
