// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// From road graph to LANE GRAPH - the derivation this whole lab is about.
// PURE and DETERMINISTIC: same graph in, byte-identical model out.
//
// A road is a line a human draws. A lane is a thing a car can be on. Turning
// the first into the second is three steps, and each one is a rule a traffic
// engineer would recognise:
//
//   1. JUNCTION BOXES. Where roads meet, neither road owns the overlap. Each
//      node gets a radius large enough to clear every carriageway crossing it,
//      and lanes are trimmed back to it - so no lane ever runs through the
//      middle of a crossing.
//   2. LANE CENTERLINES. Each road carries `lanes` lanes PER DIRECTION, offset
//      to the right-hand side of the centerline (right-hand traffic). Lane 0
//      is the kerb lane.
//   3. TURN CONNECTORS. Inside the box, every arriving lane is joined to one
//      lane of every OTHER road at that node by a curve. No U-turns: an
//      arriving lane at a dead end has nowhere to go, which is precisely what
//      makes a dead end a dead end.
//
// A movement the user has BANNED (graph.bans, directed per road pair) is still
// built and still drawn - you have to be able to see what you switched off in
// order to switch it back on - but it is left out of the lane's exit list, so
// no car will ever take it. One consequence falls out for free and is worth
// noticing: ban every exit from a lane and that lane becomes a dead end.
//
// What comes out is a directed graph whose edges are drivable and whose
// vertices are junctions - the thing traffic.js walks. Lanes and connectors
// are addressed by ARRAY INDEX (stable within one derivation), so a car is
// { kind, idx, s } and nothing has to look anything up by id in the hot path.

var LANE_W = 3.5          // one travel lane, world units (a real one is ~3.5 m)
var MIN_SPAN = 2.0        // a lane shorter than this is not worth driving
var PAD_FACTOR = 1.05     // junction pad radius vs. the widest road at the node
var CONN_SAMPLES = 9      // polyline points per turn curve

// Two legs closer than this to (anti)parallel need no clearance from each
// other: they either continue straight through or overlap, and the clearance
// formula would divide by a vanishing sine.
var SIN_EPS = 0.15

function halfWidth(road) { return road.lanes * LANE_W }
function roadWidth(road) { return 2 * road.lanes * LANE_W }

// ---- the derivation --------------------------------------------------------

/*
   derive(graph) -> {
     nodes:      [ { id, x, z, degree, radius, pad } ],
     roads:      [ { id, a, b, lanes, x0,z0,x1,z1, ux,uz, length, width, span } ],
     lanes:      [ { id, roadId, dir, index, fromNode, toNode,
                     x0,z0,x1,z1, ux,uz, length, exits:[connIdx], terminal } ],
     connectors: [ { id, node, fromLane, toLane, pts:[x,z,...], cum:[...],
                     length, turn, conflicts:[connIdx] } ],
     stats: { ... }
   }
*/
function derive(graph) {
    var net = { nodes: [], roads: [], lanes: [], connectors: [], stats: {} }
    var nodeIx = {}, roadIx = {}

    // --- 1. junction radii ---------------------------------------------------
    // A leg must be trimmed far enough back that it clears every OTHER
    // carriageway through this node. At angle t between two legs, a point d
    // along one sits d*sin(t) from the other's centerline, so clearing a
    // half-width h needs d >= h / sin(t). Near-parallel legs (a straight
    // continuation) need nothing, which is why a bend gets a box and a
    // straight-through node does not.
    for (var i = 0; i < graph.nodes.length; ++i) {
        var n = graph.nodes[i]
        var legs = _legsAt(graph, n)
        var radius = 0
        for (var a = 0; a < legs.length; ++a) {
            var need = 0
            for (var b = 0; b < legs.length; ++b) {
                if (a === b) continue
                var sin = Math.abs(legs[a].ux * legs[b].uz - legs[a].uz * legs[b].ux)
                if (sin < SIN_EPS) continue
                need = Math.max(need, halfWidth(legs[b].road) / sin)
            }
            radius = Math.max(radius, need)
        }
        // never eat more than a third of the shortest road running into the
        // node, or a short block would have no lane left between two boxes
        var cap = Infinity
        for (var c = 0; c < legs.length; ++c)
            cap = Math.min(cap, legs[c].length * 0.34)
        radius = Math.min(radius, cap)

        var maxHalf = 0
        for (var d = 0; d < legs.length; ++d)
            maxHalf = Math.max(maxHalf, halfWidth(legs[d].road))

        var rec = { id: n.id, x: n.x, z: n.z, degree: legs.length,
                    radius: radius,
                    // A fillet, not a plaza. The road ribbons already run the
                    // full length between nodes, so the crossing itself is
                    // paved by them; the disc only rounds off the notch two
                    // ribbons leave at the outer corner of a bend. Sizing it
                    // off the TRIM radius made it bulge past the kerb at every
                    // corner, which read as a blob dropped on the plan.
                    pad: maxHalf * PAD_FACTOR }
        nodeIx[n.id] = net.nodes.length
        net.nodes.push(rec)
    }

    // --- 2. roads and their lanes -------------------------------------------
    for (var r = 0; r < graph.roads.length; ++r) {
        var road = graph.roads[r]
        var na = net.nodes[nodeIx[road.a]], nb = net.nodes[nodeIx[road.b]]
        if (!na || !nb) continue
        var dx = nb.x - na.x, dz = nb.z - na.z
        var len = Math.hypot(dx, dz)
        if (len < 1e-6) continue
        var ux = dx / len, uz = dz / len

        // trimmed span: [t0, t1] along the centerline, junction boxes removed
        var t0 = na.radius, t1 = len - nb.radius
        if (t1 - t0 < MIN_SPAN) {
            // both boxes want more than the road has; split what is left
            var mid = len / 2, half = Math.max(MIN_SPAN, len * 0.12) / 2
            t0 = mid - half; t1 = mid + half
        }

        var rrec = { id: road.id, a: road.a, b: road.b, lanes: road.lanes,
                     x0: na.x, z0: na.z, x1: nb.x, z1: nb.z,
                     ux: ux, uz: uz, length: len, width: roadWidth(road),
                     t0: t0, t1: t1 }
        roadIx[road.id] = net.roads.length
        net.roads.push(rrec)

        // right-hand normal: cross(forward, up) in a Y-up frame
        var rx = -uz, rz = ux

        for (var dir = 1; dir >= -1; dir -= 2) {
            for (var k = 0; k < road.lanes; ++k) {
                var off = (k + 0.5) * LANE_W * dir
                var ox = rx * off, oz = rz * off
                var sA = dir > 0 ? t0 : t1
                var sB = dir > 0 ? t1 : t0
                net.lanes.push({
                    id: net.lanes.length,
                    roadId: road.id, dir: dir, index: k,
                    fromNode: dir > 0 ? road.a : road.b,
                    toNode: dir > 0 ? road.b : road.a,
                    x0: na.x + ux * sA + ox, z0: na.z + uz * sA + oz,
                    x1: na.x + ux * sB + ox, z1: na.z + uz * sB + oz,
                    ux: ux * dir, uz: uz * dir,
                    length: Math.abs(t1 - t0),
                    exits: [], terminal: false
                })
            }
        }
    }

    // --- 3. turn connectors --------------------------------------------------
    // Arriving lane -> one lane of every other road at this node. The target
    // index mirrors the source (kerb lane to kerb lane), clamped to what the
    // target road actually has, so a fan never crosses itself.
    for (var nn = 0; nn < net.nodes.length; ++nn) {
        var node = net.nodes[nn]
        var incoming = [], outgoing = []
        for (var li = 0; li < net.lanes.length; ++li) {
            if (net.lanes[li].toNode === node.id) incoming.push(li)
            if (net.lanes[li].fromNode === node.id) outgoing.push(li)
        }
        for (var ii = 0; ii < incoming.length; ++ii) {
            var L = net.lanes[incoming[ii]]
            // group the candidate exits by road so we pick ONE lane per road
            var byRoad = {}
            for (var oi = 0; oi < outgoing.length; ++oi) {
                var M = net.lanes[outgoing[oi]]
                if (M.roadId === L.roadId) continue      // no U-turns
                if (!byRoad[M.roadId]) byRoad[M.roadId] = []
                byRoad[M.roadId].push(outgoing[oi])
            }
            // roads in net order, so connector ids are derivation-stable
            for (var ri = 0; ri < net.roads.length; ++ri) {
                var cand = byRoad[net.roads[ri].id]
                if (!cand || !cand.length) continue
                var pick = cand[0]
                for (var ci = 0; ci < cand.length; ++ci)
                    if (net.lanes[cand[ci]].index === Math.min(L.index,
                            net.roads[ri].lanes - 1)) pick = cand[ci]
                var banned = _isBanned(graph, node.id, L.roadId, net.roads[ri].id)
                net.connectors.push(
                    _makeConnector(net, node, incoming[ii], pick, banned))
            }
        }
    }
    for (var ce = 0; ce < net.connectors.length; ++ce) {
        net.connectors[ce].id = ce
        // a banned movement exists, and is drawn, but is not an exit
        if (!net.connectors[ce].banned)
            net.lanes[net.connectors[ce].fromLane].exits.push(ce)
    }
    // a lane with no way out ends the journey: this is the dead end
    var deadEnds = 0
    for (var le = 0; le < net.lanes.length; ++le) {
        net.lanes[le].terminal = net.lanes[le].exits.length === 0
        if (net.lanes[le].terminal) ++deadEnds
    }

    _findConflicts(net)

    var laneLen = 0
    for (var ll = 0; ll < net.lanes.length; ++ll) laneLen += net.lanes[ll].length
    var bannedCount = 0
    for (var bc = 0; bc < net.connectors.length; ++bc)
        if (net.connectors[bc].banned) ++bannedCount
    net.stats = {
        nodes: net.nodes.length, roads: net.roads.length,
        lanes: net.lanes.length, connectors: net.connectors.length,
        bannedTurns: bannedCount,
        junctions: net.nodes.filter(function (x) { return x.degree >= 3 }).length,
        deadEnds: deadEnds,
        laneLength: laneLen,
        conflictPairs: net.connectors.reduce(function (s, c) {
            return s + c.conflicts.length }, 0) / 2
    }
    return net
}

function _legsAt(graph, node) {
    var legs = []
    for (var i = 0; i < graph.roads.length; ++i) {
        var r = graph.roads[i]
        var other = r.a === node.id ? r.b : (r.b === node.id ? r.a : -1)
        if (other === -1) continue
        var o = null
        for (var j = 0; j < graph.nodes.length; ++j)
            if (graph.nodes[j].id === other) o = graph.nodes[j]
        if (!o) continue
        var dx = o.x - node.x, dz = o.z - node.z
        var len = Math.hypot(dx, dz)
        if (len < 1e-6) continue
        legs.push({ road: r, ux: dx / len, uz: dz / len, length: len })
    }
    return legs
}

// A turn is a quadratic bezier whose control point is where the two lanes'
// own lines cross - so the curve leaves along the incoming lane and arrives
// along the outgoing one, which is what makes a fan of turns look drawn
// rather than interpolated.
function _isBanned(graph, node, fromRoad, toRoad) {
    var bans = graph.bans
    if (!bans) return false
    for (var i = 0; i < bans.length; ++i)
        if (bans[i].node === node && bans[i].from === fromRoad
            && bans[i].to === toRoad) return true
    return false
}

function _makeConnector(net, node, fromIdx, toIdx, banned) {
    var L = net.lanes[fromIdx], M = net.lanes[toIdx]
    var p0x = L.x1, p0z = L.z1
    var p2x = M.x0, p2z = M.z0

    var den = L.ux * (-M.uz) - L.uz * (-M.ux)
    var cx, cz
    if (Math.abs(den) < 1e-6) {
        cx = (p0x + p2x) / 2; cz = (p0z + p2z) / 2
    } else {
        var t = ((p2x - p0x) * (-M.uz) - (p2z - p0z) * (-M.ux)) / den
        if (t <= 0.01) { cx = (p0x + p2x) / 2; cz = (p0z + p2z) / 2 }
        else { cx = p0x + L.ux * t; cz = p0z + L.uz * t }
    }

    var dot = L.ux * M.ux + L.uz * M.uz
    var cross = L.ux * M.uz - L.uz * M.ux
    var turn = dot > 0.85 ? "straight"
             : (dot < -0.85 ? "back" : (cross > 0 ? "right" : "left"))

    // straight-through connectors need no curvature, and sampling them at
    // nine points would only cost the renderer vertices
    var count = turn === "straight" ? 2 : CONN_SAMPLES
    var pts = [], cum = [0], total = 0
    for (var i = 0; i < count; ++i) {
        var u = i / (count - 1), v = 1 - u
        var x = v * v * p0x + 2 * v * u * cx + u * u * p2x
        var z = v * v * p0z + 2 * v * u * cz + u * u * p2z
        pts.push(x); pts.push(z)
        if (i > 0) {
            total += Math.hypot(x - pts[(i - 1) * 2], z - pts[(i - 1) * 2 + 1])
            cum.push(total)
        }
    }
    return { id: -1, node: node.id, fromLane: fromIdx, toLane: toIdx,
             fromRoad: L.roadId, toRoad: M.roadId,
             pts: pts, cum: cum, length: Math.max(total, 0.01),
             turn: turn, banned: banned === true, conflicts: [] }
}

// Which turns may not be taken at the same time. Two connectors at one node
// conflict if their paths cross, or if they feed the SAME lane (a merge is a
// conflict even though the curves only touch at the very end).
function _findConflicts(net) {
    var byNode = {}
    for (var i = 0; i < net.connectors.length; ++i) {
        var c = net.connectors[i]
        if (c.banned) continue      // never driven, so never in anyone's way
        if (!byNode[c.node]) byNode[c.node] = []
        byNode[c.node].push(i)
    }
    for (var key in byNode) {
        var group = byNode[key]
        for (var a = 0; a < group.length; ++a)
            for (var b = a + 1; b < group.length; ++b) {
                var A = net.connectors[group[a]], B = net.connectors[group[b]]
                if (A.fromLane === B.fromLane) continue   // one car, one choice
                var hit = A.toLane === B.toLane || _pathsCross(A, B)
                if (!hit) continue
                A.conflicts.push(group[b])
                B.conflicts.push(group[a])
            }
    }
}

function _pathsCross(A, B) {
    for (var i = 0; i + 1 < A.pts.length / 2; ++i)
        for (var j = 0; j + 1 < B.pts.length / 2; ++j) {
            if (_segHit(A.pts[i * 2], A.pts[i * 2 + 1],
                        A.pts[i * 2 + 2], A.pts[i * 2 + 3],
                        B.pts[j * 2], B.pts[j * 2 + 1],
                        B.pts[j * 2 + 2], B.pts[j * 2 + 3])) return true
        }
    return false
}

function _segHit(ax, az, bx, bz, cx, cz, dx, dz) {
    var r1x = bx - ax, r1z = bz - az
    var r2x = dx - cx, r2z = dz - cz
    var den = r1x * r2z - r1z * r2x
    if (Math.abs(den) < 1e-9) return false
    var t = ((cx - ax) * r2z - (cz - az) * r2x) / den
    var u = ((cx - ax) * r1z - (cz - az) * r1x) / den
    return t > 0.02 && t < 0.98 && u > 0.02 && u < 0.98
}

// Where journeys end. One entry per degree-1 node: the point, the direction
// pointing OUT of the network, and how wide the road arriving there is - all a
// renderer needs to lay a barrier across the road rather than a blob on top
// of it.
function deadEnds(net) {
    var out = []
    for (var i = 0; i < net.nodes.length; ++i) {
        var n = net.nodes[i]
        if (n.degree !== 1) continue
        for (var r = 0; r < net.roads.length; ++r) {
            var road = net.roads[r]
            if (road.a !== n.id && road.b !== n.id) continue
            var away = road.b === n.id ? 1 : -1     // outward along the road
            out.push({ node: n.id, x: n.x, z: n.z,
                       ux: road.ux * away, uz: road.uz * away,
                       width: road.width, yaw: Math.atan2(road.ux, road.uz) })
            break
        }
    }
    return out
}

// ---- position lookup (the hot path) ----------------------------------------

// Where is a car that has travelled s along lane/connector idx?
// Returns { x, z, yaw } with yaw in radians, ready for the instance table.
function poseOn(net, kind, idx, s) {
    if (kind === 0) {
        var L = net.lanes[idx]
        var t = L.length > 1e-6 ? Math.max(0, Math.min(1, s / L.length)) : 0
        return { x: L.x0 + (L.x1 - L.x0) * t, z: L.z0 + (L.z1 - L.z0) * t,
                 yaw: Math.atan2(L.ux, L.uz) }
    }
    var C = net.connectors[idx]
    var d = Math.max(0, Math.min(C.length, s))
    var i = 1
    while (i < C.cum.length && C.cum[i] < d) ++i
    var i0 = i - 1
    var seg = C.cum[i] - C.cum[i0]
    var f = seg > 1e-6 ? (d - C.cum[i0]) / seg : 0
    var x0 = C.pts[i0 * 2], z0 = C.pts[i0 * 2 + 1]
    var x1 = C.pts[i * 2], z1 = C.pts[i * 2 + 1]
    return { x: x0 + (x1 - x0) * f, z: z0 + (z1 - z0) * f,
             yaw: Math.atan2(x1 - x0, z1 - z0) }
}

function elementLength(net, kind, idx) {
    return kind === 0 ? net.lanes[idx].length : net.connectors[idx].length
}

// ---- render helpers --------------------------------------------------------
//
// These stay POINTLESS in the Qt sense - they emit plain [x, z, x, z, ...]
// coordinate runs, never Qt.vector3d. A .pragma library script has no QML
// context, and keeping Qt out is also what lets the whole kit run under node
// for the unit suite. The QML side lifts a run into a line with one loop
// (see Streets3D.qml's toLines()).

// The asphalt: one flat ribbon per road, drawn full length. Junction pads are
// separate discs in QML, so the ribbons may simply run into them - overlapping
// asphalt is invisible, and it saves mitring every corner.
function surfaceRuns(net, color) {
    var out = []
    for (var i = 0; i < net.roads.length; ++i) {
        var r = net.roads[i]
        out.push({ xz: [r.x0, r.z0, r.x1, r.z1], roadId: r.id,
                   color: color, width: r.width, styleId: 0 })
    }
    return out
}

// The lane model overlay: centerlines plus turn curves, the map layer that
// says what the asphalt MEANS. styleOf(index, lane) picks solid vs. chevron.
function laneRuns(net, opts) {
    opts = opts || {}
    var laneColor = opts.laneColor || "#3e9b92"
    var connColor = opts.connColor || "#8a8580"
    var deadColor = opts.deadColor || "#c05621"
    var w = opts.width === undefined ? 0.32 : opts.width
    var styleOf = opts.styleOf || function () { return 0 }
    var out = []
    for (var i = 0; i < net.lanes.length; ++i) {
        var L = net.lanes[i]
        if (L.length < 0.05) continue
        out.push({ xz: [L.x0, L.z0, L.x1, L.z1],
                   roadId: L.roadId, laneIdx: i,
                   color: L.terminal ? deadColor : laneColor,
                   width: L.terminal ? w * 1.25 : w,
                   styleId: styleOf(i, L) })
    }
    if (opts.connectors !== false) {
        var banColor = opts.banColor || "#c05621"
        var banStyle = opts.banStyleId === undefined ? 0 : opts.banStyleId
        var hi = opts.highlightNode === undefined ? -1 : opts.highlightNode
        for (var c = 0; c < net.connectors.length; ++c) {
            var C = net.connectors[c]
            // Deliberately faint: the turn fan is the junction's plumbing, and
            // at a busy crossing a dozen of them would read as a scribble.
            // A BANNED movement is the exception - it is drawn in the alarm
            // colour and dashed, because a restriction you cannot see is one
            // you cannot undo. Turns at the selected junction come forward.
            var live = C.node === hi
            out.push({ xz: C.pts.slice(), roadId: -1, connIdx: c,
                       banned: C.banned, node: C.node,
                       color: C.banned ? banColor
                            : (live ? laneColor : connColor),
                       width: C.banned ? w * 0.8 : (live ? w * 0.75 : w * 0.5),
                       styleId: C.banned ? banStyle : 0 })
        }
    }
    return out
}

// Painted road furniture: the centre line between the two directions, and a
// kerb line down each edge. Trimmed to the same span as the lanes so no paint
// runs through a crossing.
function markingRuns(net, opts) {
    opts = opts || {}
    var edge = opts.edgeColor || "#f0ece4"
    var centre = opts.centreColor || "#e8d9a8"
    var out = []
    for (var i = 0; i < net.roads.length; ++i) {
        var r = net.roads[i]
        if (r.t1 - r.t0 < 0.2) continue
        var rx = -r.uz, rz = r.ux
        var ax = r.x0 + r.ux * r.t0, az = r.z0 + r.uz * r.t0
        var bx = r.x0 + r.ux * r.t1, bz = r.z0 + r.uz * r.t1
        out.push({ xz: [ax, az, bx, bz], roadId: r.id, kind: "centre",
                   color: centre, width: 0.34, styleId: 0 })
        var h = r.lanes * LANE_W
        for (var s = -1; s <= 1; s += 2) {
            out.push({ xz: [ax + rx * h * s, az + rz * h * s,
                            bx + rx * h * s, bz + rz * h * s],
                       roadId: r.id, kind: "edge",
                       color: edge, width: 0.26, styleId: 0 })
        }
    }
    return out
}
