// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the schematic panel's layout arithmetic.
//
//     node labs/kits/circuit/plan.test.js
//
// Two things here are expensive to get wrong and cheap to check. The fit is
// the drawing's honesty: a scale that is not uniform draws a board nobody
// built, and a scale that overflows draws parts nobody can see. The lettering
// is the drawing's legibility: a name on top of a symbol, a name on top of
// another name, or a name half off the panel are each worse than no name at
// all, so the suite asserts the absence of all three on a board packed as
// tightly as the XOR preset packs one.
const K = require('../kitcheck.js')

const P = K.load(__dirname, 'plan.js',
                 ['fitBox', 'placeLabels', 'overlaps', 'collides',
                  'textBox', 'readable'])

const pt = (x, y) => ({ x: x, y: y })
const rect = (x, y, w, h) => ({ x: x, y: y, w: w, h: h })

// The mapping fitBox promises, written out once so every assertion below
// checks the contract rather than a reimplementation of it.
const map = (f, p) => ({ x: f.ox + (p.x - f.cx) * f.s,
                         y: f.oy + (p.y - f.cy) * f.s })

// A symbol anchor: centre, symbol size, label size.
const anchor = (id, x, y, s, lw, lh) =>
    ({ id: id, x: x, y: y, w: s, h: s, lw: lw, lh: lh })

function allInside(pts, f, box, pad) {
    for (const p of pts) {
        const q = map(f, p)
        if (q.x < pad - 1e-6 || q.x > box.w - pad + 1e-6) return false
        if (q.y < pad - 1e-6 || q.y > box.h - pad + 1e-6) return false
    }
    return true
}

// ------------------------------------------------------------------ overlap
K.section('rectangles')
{
    K.ok('two rectangles sharing a corner region overlap',
         P.overlaps(rect(0, 0, 10, 10), rect(5, 5, 10, 10)))
    K.ok('a rectangle contained in another overlaps it',
         P.overlaps(rect(0, 0, 20, 20), rect(5, 5, 4, 4)))
    K.ok('rectangles side by side with a gap do not overlap',
         !P.overlaps(rect(0, 0, 10, 10), rect(12, 0, 10, 10)))
    // the case a gap of zero produces on every board: a label placed flush
    // against a symbol is BESIDE it, and calling that a collision would push
    // every label a pixel further out for no reason a reader could see
    K.ok('rectangles touching along an edge do not overlap',
         !P.overlaps(rect(0, 0, 10, 10), rect(10, 0, 10, 10)))
    K.ok('rectangles touching at a single corner do not overlap',
         !P.overlaps(rect(0, 0, 10, 10), rect(10, 10, 10, 10)))
    K.ok('overlapping on one axis only is not an overlap',
         !P.overlaps(rect(0, 0, 10, 10), rect(5, 40, 10, 10)))
    // an empty label (no lines to draw) must not fence off space
    K.ok('a zero-size rectangle covers nothing',
         !P.overlaps(rect(5, 5, 0, 0), rect(0, 0, 10, 10)))
}
{
    K.ok('nothing collides with an empty list', !P.collides(rect(0, 0, 5, 5), []))
    K.ok('a missing list is not a collision', !P.collides(rect(0, 0, 5, 5), null))
    K.ok('a collision anywhere in the list counts',
         P.collides(rect(0, 0, 5, 5), [rect(90, 90, 5, 5), rect(2, 2, 5, 5)]))
    K.ok('a clear rectangle reports clear',
         !P.collides(rect(0, 0, 5, 5), [rect(90, 90, 5, 5), rect(20, 2, 5, 5)]))
}

// ------------------------------------------------------------------ fitting
K.section('fitting points into a box')
{
    const box = { w: 250, h: 176 }, pad = 26
    const pts = [pt(0, 0), pt(6, 0), pt(6, 4), pt(3, 2), pt(0, 4)]
    const f = P.fitBox(pts, box, pad)
    K.ok('every point lands inside the padded box', allInside(pts, f, box, pad))
    // uniform is the whole point: a stretched schematic is a schematic of a
    // board that was never built
    const a = map(f, pt(0, 0)), b = map(f, pt(6, 4))
    K.near('the same scale is used on both axes',
           (b.x - a.x) / 6, (b.y - a.y) / 4, 1e-9)
    K.near('and it is the scale that was reported', (b.x - a.x) / 6, f.s, 1e-9)
    K.near('the drawing is centred on the box', f.ox, 125)
    K.near('vertically too', f.oy, 88)
    K.near('around the middle of the points', f.cx, 3)
    K.near('on both axes', f.cy, 2)
}
{
    // wide points in a wide-ish box: the limiting axis decides, and the other
    // one keeps slack rather than stretching to fill
    const box = { w: 200, h: 200 }, pad = 10
    const pts = [pt(0, 0), pt(20, 0), pt(20, 2)]
    const f = P.fitBox(pts, box, pad)
    K.near('a wide set of points is limited by the width', f.s, 180 / 20, 1e-9)
    K.ok('and still fits vertically', allInside(pts, f, box, pad))
}
{
    const box = { w: 200, h: 200 }, pad = 10
    const pts = [pt(0, 0), pt(2, 0), pt(2, 20)]
    const f = P.fitBox(pts, box, pad)
    K.near('a tall set of points is limited by the height', f.s, 180 / 20, 1e-9)
}
{
    // the empty pegboard: the panel exists before anything is on it
    const f = P.fitBox([], { w: 250, h: 176 }, 26)
    K.ok('an empty board still yields a positive finite scale',
         isFinite(f.s) && f.s > 0)
    K.near('and puts its origin in the middle of the panel', f.ox, 125)
    K.near('on both axes', f.oy, 88)
}
{
    // one part on the board: it belongs in the middle, at a size a human can
    // see, not magnified until it fills the panel
    const box = { w: 250, h: 176 }, pad = 26
    const f = P.fitBox([pt(7, 3)], box, pad)
    K.ok('a single point yields a positive finite scale',
         isFinite(f.s) && f.s > 0)
    const q = map(f, pt(7, 3))
    K.near('and lands dead centre', q.x, 125)
    K.near('on both axes', q.y, 88)
}
{
    // two parts stacked on the same peg: span zero on both axes, which is the
    // divide-by-zero the floor exists for
    const box = { w: 250, h: 176 }, pad = 26
    const pts = [pt(4, 4), pt(4, 4), pt(4, 4)]
    const f = P.fitBox(pts, box, pad)
    K.ok('identical points do not divide by zero', isFinite(f.s) && f.s > 0)
    K.ok('and they all land inside the padded box', allInside(pts, f, box, pad))
}
{
    // mid-resize the panel is briefly narrower than its own margins
    const f = P.fitBox([pt(0, 0), pt(5, 5)], { w: 20, h: 20 }, 40)
    K.ok('a box smaller than its padding still yields a positive scale',
         isFinite(f.s) && f.s > 0)
}
{
    const f = P.fitBox([pt(0, 0), pt(5, 5)], { w: 0, h: 0 }, 0)
    K.ok('a zero-size box still yields a positive scale',
         isFinite(f.s) && f.s > 0)
}
{
    // pad is a promise, not a hint: the caller draws a border in that margin
    const box = { w: 300, h: 120 }, pad = 30
    const pts = []
    for (let c = 0; c < 8; ++c) for (let r = 0; r < 5; ++r) pts.push(pt(c, r))
    const f = P.fitBox(pts, box, pad)
    K.ok('a full grid of points respects the padding',
         allInside(pts, f, box, pad))
    // the tighter axis is the one that touches its margin; the other keeps
    // the slack, because filling it would mean two different scales
    K.near('the limiting axis sits exactly on the margin',
           map(f, pt(0, 0)).y, pad, 1e-6)
    K.ok('and the roomier axis keeps its slack',
         map(f, pt(0, 0)).x > pad + 1e-6)
}
{
    // negative coordinates happen the moment the board is centred on the origin
    const box = { w: 100, h: 100 }, pad = 5
    const pts = [pt(-9, -4), pt(3, 6)]
    const f = P.fitBox(pts, box, pad)
    K.ok('points either side of the origin fit too', allInside(pts, f, box, pad))
    K.near('and the centre is between them, not at zero', f.cx, -3)
}
{
    // the panel is repainted on every model change; a fit that wandered would
    // make the whole diagram twitch
    const pts = [pt(0, 0), pt(4, 7), pt(9, 2)]
    const one = JSON.stringify(P.fitBox(pts, { w: 250, h: 176 }, 26))
    const two = JSON.stringify(P.fitBox(pts, { w: 250, h: 176 }, 26))
    K.eq('the same points fit the same way twice', one, two)
}

// ------------------------------------------------------------------ text
K.section('text blocks')
{
    const b = P.textBox(['R1', '470 Ω'], 7, 12)
    K.near('a block is as wide as its longest line', b.w, 35)
    K.near('and as tall as the number of lines', b.h, 24)
}
{
    const b = P.textBox([], 7, 12)
    K.near('no lines means no width', b.w, 0)
    K.near('and no height', b.h, 0)
}
{
    K.near('a single line block is one line tall', P.textBox(['R1'], 7, 12).h, 12)
    // a measured value is added only when the meter has one, so the middle
    // line is sometimes absent and sometimes empty
    K.near('an empty line still takes its height', P.textBox(['', ''], 7, 12).h, 24)
    K.near('but adds no width', P.textBox(['', ''], 7, 12).w, 0)
}
{
    K.near('a missing line is treated as empty',
           P.textBox(['R1', null], 7, 12).w, 14)
}

// ------------------------------------------------------------------ threshold
K.section('is there room to letter at all')
{
    K.ok('a generous scale is readable', P.readable(60, 34))
    K.ok('a cramped scale is not', !P.readable(12, 34))
    K.ok('exactly at the threshold counts as readable', P.readable(34, 34))
    K.ok('just under does not', !P.readable(33.9, 34))
    // fitBox never produces this, but a caller doing its own arithmetic might
    K.ok('a non-finite scale is never readable', !P.readable(Infinity, 34))
    K.ok('and neither is a nonsense one', !P.readable(NaN, 34))
    K.ok('a threshold of zero lets everything through', P.readable(0.5, 0))
}

// ------------------------------------------------------------------ spacious
K.section('lettering a board with room on it')
{
    // three parts far enough apart that nothing has to compromise
    const box = { w: 600, h: 400 }
    const anchors = [anchor(1, 100, 100, 24, 60, 26),
                     anchor(2, 300, 100, 24, 60, 26),
                     anchor(3, 200, 260, 24, 60, 26)]
    const out = P.placeLabels(anchors, { gap: 4, box: box })
    K.eq('every anchor gets an answer', out.length, 3)
    let allBelow = true, allPlaced = true
    for (const l of out) { if (l.side !== 'below') allBelow = false
                           if (!l.placed) allPlaced = false }
    K.ok('with room to spare every label takes its first-choice side', allBelow)
    K.ok('and every one reports itself placed', allPlaced)
    K.near('a label is centred under its symbol', out[0].x, 100 - 30)
    K.near('and sits a gap below its edge', out[0].y, 100 + 12 + 4)
    K.eq('the ids come back in the order they were given', out[1].id, 2)
}
{
    // the label must clear the symbol even when the caller asks for no gap
    const out = P.placeLabels([anchor(1, 100, 100, 24, 60, 26)],
                              { gap: 0, box: { w: 600, h: 400 } })
    K.ok('a label never lands on its own symbol',
         !P.overlaps(out[0], { x: 88, y: 88, w: 24, h: 24 }))
    K.ok('and a zero gap still counts as placed', out[0].placed)
}
{
    // a part at the bottom of the panel: below leaves the box, so the next
    // side in the order has to take it
    const box = { w: 400, h: 200 }
    const out = P.placeLabels([anchor(1, 200, 185, 20, 60, 26)],
                              { gap: 4, box: box })
    K.eq('a part against the bottom edge is lettered above instead',
         out[0].side, 'above')
    K.ok('and the label is inside the panel',
         out[0].y >= 0 && out[0].y + out[0].h <= box.h)
}
{
    // a part against the left edge keeps its side and slides sideways: moving
    // it out of the panel to preserve the centring would be the worse trade
    const box = { w: 400, h: 300 }
    const out = P.placeLabels([anchor(1, 10, 100, 20, 80, 26)],
                              { gap: 4, box: box })
    K.eq('a part against the left edge is still lettered below', out[0].side, 'below')
    K.near('with the label slid back inside the panel', out[0].x, 0)
}
{
    // a caller that only has room on one flank may say so
    const box = { w: 600, h: 400 }
    const out = P.placeLabels([anchor(1, 100, 100, 24, 60, 26),
                               anchor(2, 300, 100, 24, 60, 26)],
                              { gap: 4, box: box, sides: ['right'] })
    K.eq('a restricted side list is honoured', out[0].side, 'right')
    K.eq('for every anchor', out[1].side, 'right')
    K.near('and the label starts a gap past the symbol edge',
           out[0].x, 100 + 12 + 4)
    K.near('vertically centred on it', out[0].y, 100 - 13)
}
{
    // wires are the caller's business, not this file's, but a caller that
    // knows where they run may hand them over
    const box = { w: 600, h: 400 }
    const wire = rect(60, 116, 200, 8)     // straight under the only part
    const out = P.placeLabels([anchor(1, 100, 100, 24, 60, 26)],
                              { gap: 4, box: box, avoid: [wire] })
    K.ok('a label keeps off a rectangle the caller asked it to avoid',
         !P.overlaps(out[0], wire))
    K.ok('and still finds somewhere to go', out[0].placed)
}

// ------------------------------------------------------------------ contested
K.section('who wins a contested spot')
{
    // two parts close enough that only one label fits below
    const box = { w: 600, h: 400 }
    const a = anchor('A', 100, 100, 20, 60, 24)
    const b = anchor('B', 130, 100, 20, 60, 24)
    const out = P.placeLabels([a, b], { gap: 4, box: box })
    K.eq('the earlier anchor keeps the contested side', out[0].side, 'below')
    K.ok('the later one is moved off it', out[1].side !== 'below')
    K.ok('and both are still placed', out[0].placed && out[1].placed)
    K.ok('the two labels do not overlap', !P.overlaps(out[0], out[1]))

    // the same two parts in the other order: the rule is about list position,
    // not about coordinates, which is what makes a repaint reproducible
    const rev = P.placeLabels([b, a], { gap: 4, box: box })
    K.eq('reversing the list reverses who wins', rev[0].id, 'B')
    K.eq('and the winner takes the same side', rev[0].side, 'below')
    K.ok('while the loser is moved off it', rev[1].side !== 'below')
}
{
    // an unplaced label must not fence off space it may never be drawn in
    const box = { w: 90, h: 90 }
    const tight = [anchor(1, 45, 45, 30, 200, 200),   // label far bigger than the box
                   anchor(2, 45, 45, 30, 40, 20)]
    const out = P.placeLabels(tight, { gap: 4, box: box })
    K.ok('a label with nowhere to go reports itself unplaced', !out[0].placed)
    K.ok('but is still given a position to draw at',
         isFinite(out[0].x) && isFinite(out[0].y))
    K.eq('and the first-choice side is the one it reports', out[0].side, 'below')
}

// ------------------------------------------------------------------ crowded
K.section('lettering the board the XOR preset builds')
{
    // twenty parts on a tight grid: symbols 20 across on a 30 pitch, with a
    // two-line label wider than the pitch. Most sides are genuinely blocked,
    // and the point of the case is that what comes back is honest about it
    // rather than a neat pile of overlapping text.
    const box = { w: 260, h: 220 }
    const anchors = []
    for (let r = 0; r < 4; ++r)
        for (let c = 0; c < 5; ++c)
            anchors.push(anchor(r * 5 + c, 45 + c * 30, 45 + r * 30, 20, 40, 24))
    K.eq('the board really does have twenty parts', anchors.length, 20)

    const out = P.placeLabels(anchors, { gap: 4, box: box })
    K.eq('every part gets an answer', out.length, 20)

    const symbols = anchors.map(a => rect(a.x - a.w / 2, a.y - a.h / 2, a.w, a.h))
    const placed = out.filter(l => l.placed)

    let onSymbol = 0
    for (const l of placed)
        for (const s of symbols) if (P.overlaps(l, s)) ++onSymbol
    K.eq('no label is drawn over a symbol', onSymbol, 0)

    let onLabel = 0
    for (let i = 0; i < placed.length; ++i)
        for (let j = i + 1; j < placed.length; ++j)
            if (P.overlaps(placed[i], placed[j])) ++onLabel
    K.eq('no label is drawn over another label', onLabel, 0)

    let outside = 0
    for (const l of placed)
        if (l.x < -1e-6 || l.y < -1e-6
            || l.x + l.w > box.w + 1e-6 || l.y + l.h > box.h + 1e-6) ++outside
    K.eq('no label leaves the panel', outside, 0)

    K.ok('a crowd this tight leaves some labels unplaced rather than stacked',
         placed.length < out.length)
    K.ok('and it still letters what it can', placed.length > 0)

    // the diagram is repainted on every solve; a layout that reshuffled would
    // make the names crawl around the board while a switch is being flipped
    const again = P.placeLabels(anchors, { gap: 4, box: box })
    K.eq('the same crowd letters identically on a repaint',
         JSON.stringify(out), JSON.stringify(again))
}
{
    // the same grid with breathing room: nothing is contested, so every label
    // should get its first choice and none should be dropped
    const box = { w: 700, h: 560 }
    const anchors = []
    for (let r = 0; r < 4; ++r)
        for (let c = 0; c < 5; ++c)
            anchors.push(anchor(r * 5 + c, 70 + c * 120, 70 + r * 120, 24, 60, 24))
    const out = P.placeLabels(anchors, { gap: 4, box: box })
    let firstChoice = 0, unplaced = 0
    for (const l of out) { if (l.side === 'below') ++firstChoice
                           if (!l.placed) ++unplaced }
    K.eq('a spacious board letters every part below it', firstChoice, 20)
    K.eq('and drops none of them', unplaced, 0)
}
{
    K.eq('no anchors means no labels', P.placeLabels([], {}).length, 0)
    K.eq('and a missing list is not a crash', P.placeLabels(null).length, 0)
    // the panel size is optional: a caller measuring before it has a size
    // still gets a usable layout
    const free = P.placeLabels([anchor(1, 0, 0, 20, 40, 20)], {})
    K.ok('without a box a label is placed anyway', free[0].placed)
    K.eq('on its first-choice side', free[0].side, 'below')
}

process.exit(K.report('circuit plan'))
