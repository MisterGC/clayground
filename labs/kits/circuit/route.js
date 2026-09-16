// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Manhattan wire routing for the circuit kit.
//
// A wire on this board used to be the straight line between two pads. That is
// right for the rails, where the pads are already in line, and wrong for
// everything else: five transistors and a lamp produce a fan of diagonals that
// says nothing about the circuit, because a diagonal has no relationship to the
// grid the parts stand on. Every board people actually solder, and every
// diagram people actually draw, runs its wires along two axes and turns at
// right angles.
//
// So this file answers one question - given two pads, what path do we draw
// between them - and answers it in three moves:
//
//   1. A LEAD LEAVES ITS PAD ALONG THE PAD'S OWN DIRECTION. A resistor's wire
//      leaves the end of the resistor; a transistor's base lead leaves the base
//      side. That single rule is what makes a routed board read as wired rather
//      than as connected.
//   2. BETWEEN THE TWO LEADS, ONLY RIGHT ANGLES. One corner where the two leads
//      are on different axes, two where they are on the same one.
//   3. WHERE THE TURN HAPPENS IS A CHOICE, so it is made by scoring: a handful
//      of candidate paths, and the cheapest wins. Crossing a part that the wire
//      has nothing to do with is expensive, running on top of a wire already
//      routed is expensive, a corner costs a little, length costs least.
//
// Geometry only - no Qt types, no currents, no ids of its own - so
// route.test.js can check it under node in a second.
.pragma library

// --- tunables ---------------------------------------------------------------

// How far a lead runs out of its pad before the route may turn. A part body
// reaches ~1 unit past its outermost pad, so this clears the case.
var STUB = 1.8

// Two pads this close on an axis count as in line, and the wire between them
// is the straight one. This is what keeps every rail exactly as it was: a
// deliberate jog of a tenth of a unit would be a worse picture than a slope
// nobody can see.
var ALIGNED = 0.55

// How much room a route keeps around a part body it is passing.
var CLEAR = 0.7

// The scoring weights, in units of board length so they can be compared with
// one another. Crossing a part is worth a long detour; a corner is worth a
// short one; going out of a pad backwards is nearly as bad as a crossing,
// because it draws the lead over its own part.
var COST_HIT = 900
var COST_BACK = 400
var COST_BEND = 7

// Sharing is charged BY THE UNIT, not by the incident: a wire hidden under
// another for twenty units has effectively been rubbed out, while one that
// touches for two has not. At two and a half times the price of length, a
// wire will go round rather than lie on top of a long run, and will not
// bother for a short one.
var COST_SHARE = 2.5

// An overlap shorter than this is a touch at a corner, not a wire hiding
// under another wire.
var SHARE_MIN = 1.0

function _v(x, z) { return { x: x, z: z } }
function _snap(v, g) { return g > 0 ? Math.round(v / g) * g : v }

// Which axis a lead direction runs along: "h" along x, "v" along z.
function _axisOf(d) { return Math.abs(d.x) >= Math.abs(d.z) ? "h" : "v" }

// --- path arithmetic --------------------------------------------------------

// Drops repeated and collinear points, so a candidate that degenerates into a
// straight line is scored as one (no phantom corners) and the batch draws the
// fewest segments the shape needs.
function clean(pts) {
    var out = []
    var i
    for (i = 0; i < pts.length; ++i) {
        var p = pts[i]
        if (out.length) {
            var q = out[out.length - 1]
            if (Math.abs(q.x - p.x) < 1e-6 && Math.abs(q.z - p.z) < 1e-6) continue
        }
        out.push(_v(p.x, p.z))
    }
    if (out.length < 3) return out
    var res = [out[0]]
    for (i = 1; i < out.length - 1; ++i) {
        var a = res[res.length - 1], b = out[i], c = out[i + 1]
        var cross = (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
        if (Math.abs(cross) < 1e-6) continue
        res.push(b)
    }
    res.push(out[out.length - 1])
    return res
}

function pathLength(pts) {
    var d = 0
    for (var i = 0; i + 1 < pts.length; ++i)
        d += Math.hypot(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z)
    return d
}

// The nearest point on a path to (x, z): what a click on a wire means now that
// a wire is not a segment. Carries the distance, so the hit test can use it,
// and the point itself, so dropping a junction lands ON the drawn wire.
function closestOnPath(pts, x, z) {
    var best = { x: pts.length ? pts[0].x : 0, z: pts.length ? pts[0].z : 0,
                 dist: Infinity, seg: 0, t: 0 }
    for (var i = 0; i + 1 < pts.length; ++i) {
        var a = pts[i], b = pts[i + 1]
        var dx = b.x - a.x, dz = b.z - a.z
        var len2 = dx * dx + dz * dz
        var t = len2 < 1e-9 ? 0
            : Math.max(0, Math.min(1, ((x - a.x) * dx + (z - a.z) * dz) / len2))
        var px = a.x + t * dx, pz = a.z + t * dz
        var d = Math.hypot(px - x, pz - z)
        if (d < best.dist) best = { x: px, z: pz, dist: d, seg: i, t: t }
    }
    return best
}

// The point half a path's length along it - where a wire's reading belongs.
// The mean of the two ends is the wrong place once a wire has corners: on an
// L it sits off the wire entirely.
function midOfPath(pts) {
    if (!pts.length) return _v(0, 0)
    if (pts.length === 1) return _v(pts[0].x, pts[0].z)
    var half = pathLength(pts) / 2
    for (var i = 0; i + 1 < pts.length; ++i) {
        var a = pts[i], b = pts[i + 1]
        var seg = Math.hypot(b.x - a.x, b.z - a.z)
        if (seg >= half) {
            var t = seg < 1e-9 ? 0 : half / seg
            return _v(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t)
        }
        half -= seg
    }
    return _v(pts[pts.length - 1].x, pts[pts.length - 1].z)
}

// --- scoring ----------------------------------------------------------------

// An axis-aligned segment against an axis-aligned box: the segment's own
// bounding box IS the segment, so this is exact rather than conservative.
function _hitsBox(a, b, box) {
    var x0 = Math.min(a.x, b.x), x1 = Math.max(a.x, b.x)
    var z0 = Math.min(a.z, b.z), z1 = Math.max(a.z, b.z)
    return x1 > box.x - box.hx && x0 < box.x + box.hx
        && z1 > box.z - box.hz && z0 < box.z + box.hz
}

// Segments already spoken for, indexed by the line they lie on, so asking
// "is anything else already running here?" is a lookup rather than a scan of
// every wire on the board.
function occupancy() {
    return { lanes: {},
             add: function (a, b) {
                 var horiz = Math.abs(a.z - b.z) < 1e-6
                 var vert = Math.abs(a.x - b.x) < 1e-6
                 if (!horiz && !vert) return
                 var key = horiz ? ("h" + (Math.round(a.z * 4) / 4).toFixed(2))
                                 : ("v" + (Math.round(a.x * 4) / 4).toFixed(2))
                 var lo = horiz ? Math.min(a.x, b.x) : Math.min(a.z, b.z)
                 var hi = horiz ? Math.max(a.x, b.x) : Math.max(a.z, b.z)
                 if (!this.lanes[key]) this.lanes[key] = []
                 this.lanes[key].push([lo, hi])
             },
             overlaps: function (a, b) {
                 var horiz = Math.abs(a.z - b.z) < 1e-6
                 var vert = Math.abs(a.x - b.x) < 1e-6
                 if (!horiz && !vert) return 0
                 var key = horiz ? ("h" + (Math.round(a.z * 4) / 4).toFixed(2))
                                 : ("v" + (Math.round(a.x * 4) / 4).toFixed(2))
                 var lane = this.lanes[key]
                 if (!lane) return 0
                 var lo = horiz ? Math.min(a.x, b.x) : Math.min(a.z, b.z)
                 var hi = horiz ? Math.max(a.x, b.x) : Math.max(a.z, b.z)
                 var n = 0
                 for (var i = 0; i < lane.length; ++i) {
                     var o = Math.min(hi, lane[i][1]) - Math.max(lo, lane[i][0])
                     if (o > SHARE_MIN) n += o
                 }
                 return n
             } }
}

// What a candidate path costs. Everything is in board units, so the weights
// above are readable as "worth this many units of detour".
function scorePath(pts, obstacles, taken, dirA, dirB) {
    var len = 0, hits = 0, shared = 0, back = 0
    for (var i = 0; i + 1 < pts.length; ++i) {
        var a = pts[i], b = pts[i + 1]
        len += Math.abs(b.x - a.x) + Math.abs(b.z - a.z)
        // one hit per segment is enough to condemn it, and stopping there is
        // what keeps a search over ~70 candidates off the drag path
        for (var j = 0; j < obstacles.length; ++j)
            if (_hitsBox(a, b, obstacles[j])) { ++hits; break }
        if (taken) shared += taken.overlaps(a, b)
    }
    // A lead that starts by going the wrong way runs back over its own part.
    if (pts.length > 1 && dirA) {
        var f = _v(pts[1].x - pts[0].x, pts[1].z - pts[0].z)
        if (f.x * dirA.x + f.z * dirA.z < -1e-6) ++back
    }
    if (pts.length > 1 && dirB) {
        var n = pts.length - 1
        var l = _v(pts[n - 1].x - pts[n].x, pts[n - 1].z - pts[n].z)
        if (l.x * dirB.x + l.z * dirB.z < -1e-6) ++back
    }
    return hits * COST_HIT + back * COST_BACK
         + Math.max(0, pts.length - 2) * COST_BEND
         + shared * COST_SHARE + len
}

// --- candidates -------------------------------------------------------------

// Where a route is allowed to turn, given which axis it must leave on and
// which axis it must arrive on. The free coordinate is the CHANNEL: the line
// the middle of the route runs along. Candidates are the midpoint, a few
// pegs either side of it, and the two positions that hug one end or the other.
// `edges` are the lines just clear of whatever is standing nearby, on the axis
// the channel runs on. A blind ladder of offsets misses a part by a fraction as
// easily as it clears it; the sides of the parts themselves are where a route
// wants to pass, so they are candidates in their own right.
function _channels(from, to, grid, edges) {
    var mid = (from + to) / 2
    var out = [_snap(mid, grid)]
    for (var k = 1; k <= 2; ++k) {
        out.push(_snap(mid + k * grid, grid))
        out.push(_snap(mid - k * grid, grid))
    }
    out.push(from)
    out.push(to)
    if (edges) for (var i = 0; i < edges.length; ++i) out.push(edges[i])
    return out
}

// Just outside each nearby part, on one axis. Half a wire's width of air, so
// the ribbon does not graze the body it is passing.
function _edgesOf(obstacles, vert) {
    var out = []
    for (var i = 0; i < obstacles.length; ++i) {
        var o = obstacles[i]
        var h = vert ? o.hz : o.hx
        var c = vert ? o.z : o.x
        out.push(c - h - 0.55)
        out.push(c + h + 0.55)
    }
    return out
}

// Both leads on the same axis: out, across, along, back, in. The way round
// something standing in the direct lane. `vert` swaps the roles of x and z, so
// the two same-axis cases are one shape written once.
function _stepOver(out, p1, p2, grid, vert, edges) {
    var a0 = vert ? p1.z : p1.x, b0 = vert ? p2.z : p2.x
    var a1 = vert ? p1.x : p1.z, b1 = vert ? p2.x : p2.z
    var span = b0 - a0
    var turns = [[a0, b0], [_snap(a0 + span * 0.25, grid), _snap(b0 - span * 0.25, grid)]]
    var cross = _channels(a1, b1, grid, edges)
    for (var t = 0; t < turns.length; ++t)
        for (var k = 0; k < cross.length; ++k) {
            var c = cross[k], qa = turns[t][0], qb = turns[t][1]
            out.push(vert ? [_v(a1, qa), _v(c, qa), _v(c, qb), _v(b1, qb)]
                          : [_v(qa, a1), _v(qa, c), _v(qb, c), _v(qb, b1)])
        }
}

function _candidates(p1, ax1, p2, ax2, grid, ex, ez) {
    var out = []
    var cs, i
    if (ax1 === "h" && ax2 === "h") {
        cs = _channels(p1.x, p2.x, grid, ex)
        for (i = 0; i < cs.length; ++i) out.push([_v(cs[i], p1.z), _v(cs[i], p2.z)])
        // Two pads on the same row need no corner at all - until something is
        // standing between them, and then the only way past is over or under.
        // Four corners, so this is never chosen unless the direct lane is
        // genuinely blocked. It turns at the ends of the two leads (and one
        // peg further in, for when the thing in the way is right beside a pad).
        _stepOver(out, p1, p2, grid, false, ez)
    } else if (ax1 === "v" && ax2 === "v") {
        cs = _channels(p1.z, p2.z, grid, ez)
        for (i = 0; i < cs.length; ++i) out.push([_v(p1.x, cs[i]), _v(p2.x, cs[i])])
        _stepOver(out, p1, p2, grid, true, ex)
    } else if (ax1 === "h") {                       // out sideways, in from above
        out.push([_v(p2.x, p1.z)])                  // the plain elbow
        // and, for when the elbow crosses something, a jog: out, across, back
        cs = _channels(p1.z, p2.z, grid, ez)
        var cx = _snap((p1.x + p2.x) / 2, grid)
        for (i = 0; i < cs.length; ++i)
            out.push([_v(cx, p1.z), _v(cx, cs[i]), _v(p2.x, cs[i])])
        cs = _channels(p1.x, p2.x, grid, ex)
        var cz = _snap((p1.z + p2.z) / 2, grid)
        for (i = 0; i < cs.length; ++i)
            out.push([_v(cs[i], p1.z), _v(cs[i], cz), _v(p2.x, cz)])
    } else {                                        // out vertically, in sideways
        out.push([_v(p1.x, p2.z)])
        cs = _channels(p1.x, p2.x, grid, ex)
        var cz2 = _snap((p1.z + p2.z) / 2, grid)
        for (i = 0; i < cs.length; ++i)
            out.push([_v(p1.x, cz2), _v(cs[i], cz2), _v(cs[i], p2.z)])
        cs = _channels(p1.z, p2.z, grid, ez)
        var cx2 = _snap((p1.x + p2.x) / 2, grid)
        for (i = 0; i < cs.length; ++i)
            out.push([_v(p1.x, cs[i]), _v(cx2, cs[i]), _v(cx2, p2.z)])
    }
    return out
}

// How far the lead runs before the route may turn. Full length when the other
// end is behind this pad, and clamped when it is close in front - two pads
// three units apart must not each grow a two-unit lead and overshoot.
function _stubLen(a, b, dir) {
    if (!dir) return 0
    var along = (b.x - a.x) * dir.x + (b.z - a.z) * dir.z
    if (along <= 0) return STUB
    return Math.max(0.5, Math.min(STUB, along * 0.4))
}

// --- the router -------------------------------------------------------------

// One wire. `a` and `b` are {x, z, dir}, where dir is the direction the lead
// leaves the pad (a unit vector in x/z) or null for a solder dot, which has no
// preferred side. Returns the path, ends included.
function routeOne(a, b, obstacles, taken, grid) {
    var g = grid === undefined ? 2.5 : grid
    var obs = obstacles || []

    var da = a.dir || null, db = b.dir || null

    // In line already: the straight wire is the right wire, and this is the
    // case every rail on every preset board is in. Only when the lane between
    // the two pads is both clear and free, though - a rail with a part standing
    // on it has to go round, and a meter wired ACROSS a part sits in that
    // part's own row, where a straight lead would be drawn on top of the wire
    // already there and neither of the two would be readable.
    if (Math.abs(a.z - b.z) < ALIGNED || Math.abs(a.x - b.x) < ALIGNED) {
        var pa = _v(a.x, a.z), pb = _v(b.x, b.z)
        var clear = true
        for (var q = 0; q < obs.length; ++q)
            if (_hitsBox(pa, pb, obs[q])) { clear = false; break }
        if (clear && (!taken || taken.overlaps(pa, pb) <= 0)) return [pa, pb]
    }

    var sa = _stubLen(a, b, da), sb = _stubLen(b, a, db)
    var p1 = da ? _v(a.x + da.x * sa, a.z + da.z * sa) : _v(a.x, a.z)
    var p2 = db ? _v(b.x + db.x * sb, b.z + db.z * sb) : _v(b.x, b.z)

    // A solder dot may be left on either axis, so both are tried and the
    // scorer decides - which is usually "whichever needs one corner less".
    var axesA = da ? [_axisOf(da)] : ["h", "v"]
    var axesB = db ? [_axisOf(db)] : ["h", "v"]

    var ex = _edgesOf(obs, false)          // lines just clear of a part, along x
    var ez = _edgesOf(obs, true)           //                            along z
    var best = null
    for (var i = 0; i < axesA.length; ++i)
        for (var j = 0; j < axesB.length; ++j) {
            var cands = _candidates(p1, axesA[i], p2, axesB[j], g, ex, ez)
            for (var k = 0; k < cands.length; ++k) {
                var pts = clean([_v(a.x, a.z), p1]
                                .concat(cands[k])
                                .concat([p2, _v(b.x, b.z)]))
                var c = scorePath(pts, obs, taken, da, db)
                if (!best || c < best.cost) best = { pts: pts, cost: c }
            }
        }
    return best ? best.pts : [_v(a.x, a.z), _v(b.x, b.z)]
}

// Every wire on a board, in order. Order matters: a wire routed earlier owns
// the lane it runs in, and later wires pay to share it, which is what stops
// two wires from hiding under one another.
//
// links: [{ id, a: {x,z,dir}, b: {x,z,dir}, ends: [elementId, elementId] }]
// obstacles: [{ id, x, z, hx, hz }] - part bodies, half-extents, already
// axis-aligned. A wire ignores the parts it is wired TO.
//
// Returns { <link id>: [ {x,z}, ... ] }.
function routeAll(links, obstacles, grid) {
    var taken = occupancy()
    var out = {}
    var obs = obstacles || []
    var g = grid === undefined ? 2.5 : grid
    // No candidate path ever leaves the box the two pads span, grown by the
    // furthest a channel may be offset plus a lead - so a part outside it
    // cannot be in the way, and on a board of forty parts most wires end up
    // scoring against two or three of them instead of all of them.
    var reach = 2 * g + STUB + CLEAR + 0.5
    for (var i = 0; i < links.length; ++i) {
        var w = links[i]
        var x0 = Math.min(w.a.x, w.b.x) - reach, x1 = Math.max(w.a.x, w.b.x) + reach
        var z0 = Math.min(w.a.z, w.b.z) - reach, z1 = Math.max(w.a.z, w.b.z) + reach
        var mine = []
        for (var j = 0; j < obs.length; ++j) {
            var o = obs[j]
            if (w.ends && (w.ends[0] === o.id || w.ends[1] === o.id)) continue
            if (o.x - o.hx > x1 || o.x + o.hx < x0
                || o.z - o.hz > z1 || o.z + o.hz < z0) continue
            mine.push({ x: o.x, z: o.z, hx: o.hx + CLEAR, hz: o.hz + CLEAR })
        }
        var pts = routeOne(w.a, w.b, mine, taken, g)
        out[w.id] = pts
        for (var k = 0; k + 1 < pts.length; ++k) taken.add(pts[k], pts[k + 1])
    }
    return out
}
