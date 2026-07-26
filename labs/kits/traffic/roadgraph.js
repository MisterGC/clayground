// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The editable road graph: nodes (junctions and dead ends) joined by straight
// road segments in the XZ plane. PURE and DETERMINISTIC - no clock, no random,
// no QML. Everything the lane model and the traffic sim need is derived from
// what lives here, so this is the single source of truth for "what did the
// user build".
//
// The one invariant the whole kit rests on: THE GRAPH IS PLANAR. Two roads may
// only meet at a node, never in the middle of each other. insertRoad() keeps
// it that way by splitting whatever it crosses (and whatever it lands on), so
// a lane model can be derived by looking at one node at a time - no global
// "do these two roads secretly overlap" search anywhere downstream.
//
// Shape of the data:
//   nodes: [ { id, x, z } ]
//   roads: [ { id, a, b, lanes } ]        a/b are node ids, lanes is PER
//                                         DIRECTION (1 or 2)
// Ids are handed out from a single counter so a graph serializes and restores
// as plain JSON (see the lab's viewState).

// An endpoint this close to an existing node joins it instead of making a new
// one; this close to a road splits that road. Both are in world units and
// deliberately generous - connecting is the common intent, and a near miss
// that leaves a hairline gap would silently break the network.
var SNAP_NODE = 4.5
var SNAP_ROAD = 3.0

// Shorter than this and a road is not worth having: it cannot hold a junction
// box at both ends, let alone a car.
var MIN_LEN = 7.0

// Two crossings closer than this are the same crossing (three roads through
// one point), and share a node rather than leaving a sliver between them.
var MERGE_EPS = 1.2

function empty() { return { nodes: [], roads: [], nextId: 1 } }

// Deep copy - the lab hands these to QML properties, and a shared reference
// would mutate under bindings that think they are looking at a snapshot.
function clone(g) {
    return {
        nodes: g.nodes.map(function (n) { return { id: n.id, x: n.x, z: n.z } }),
        roads: g.roads.map(function (r) {
            return { id: r.id, a: r.a, b: r.b, lanes: r.lanes }
        }),
        nextId: g.nextId
    }
}

function nodeById(g, id) {
    for (var i = 0; i < g.nodes.length; ++i)
        if (g.nodes[i].id === id) return g.nodes[i]
    return null
}

function roadById(g, id) {
    for (var i = 0; i < g.roads.length; ++i)
        if (g.roads[i].id === id) return g.roads[i]
    return null
}

// Roads touching a node, in road order (stable, so derived ids are stable).
function incident(g, nodeId) {
    var out = []
    for (var i = 0; i < g.roads.length; ++i) {
        var r = g.roads[i]
        if (r.a === nodeId || r.b === nodeId) out.push(r)
    }
    return out
}

function degree(g, nodeId) { return incident(g, nodeId).length }

function roadLength(g, r) {
    var a = nodeById(g, r.a), b = nodeById(g, r.b)
    if (!a || !b) return 0
    return Math.hypot(b.x - a.x, b.z - a.z)
}

function addNode(g, x, z) {
    var n = { id: g.nextId++, x: x, z: z }
    g.nodes.push(n)
    return n
}

function nearestNode(g, x, z, radius) {
    var best = null, bd = radius
    for (var i = 0; i < g.nodes.length; ++i) {
        var n = g.nodes[i]
        var d = Math.hypot(n.x - x, n.z - z)
        if (d <= bd) { bd = d; best = n }
    }
    return best
}

// Closest point on a road, as { road, t, x, z, dist } - t is the normalized
// position along a->b. Endpoints are included, so callers that want a genuine
// mid-road hit must check t themselves.
function closestOnRoad(g, r, x, z) {
    var a = nodeById(g, r.a), b = nodeById(g, r.b)
    if (!a || !b) return null
    var dx = b.x - a.x, dz = b.z - a.z
    var len2 = dx * dx + dz * dz
    var t = len2 < 1e-9 ? 0
        : Math.max(0, Math.min(1, ((x - a.x) * dx + (z - a.z) * dz) / len2))
    var px = a.x + t * dx, pz = a.z + t * dz
    return { road: r, t: t, x: px, z: pz, dist: Math.hypot(px - x, pz - z) }
}

function nearestRoad(g, x, z, radius) {
    var best = null
    for (var i = 0; i < g.roads.length; ++i) {
        var c = closestOnRoad(g, g.roads[i], x, z)
        if (!c) continue
        if (c.dist <= radius && (!best || c.dist < best.dist)) best = c
    }
    return best
}

// Drops a node onto an existing road and replaces it with two roads that
// inherit its lane count. Returns the new node id (or an existing endpoint id
// when the point lands on one).
function splitRoad(g, roadId, x, z) {
    var r = roadById(g, roadId)
    if (!r) return -1
    var a = nodeById(g, r.a), b = nodeById(g, r.b)
    if (!a || !b) return -1
    // landing on an end is not a split, it is a join
    if (Math.hypot(a.x - x, a.z - z) < MERGE_EPS) return a.id
    if (Math.hypot(b.x - x, b.z - z) < MERGE_EPS) return b.id

    var n = addNode(g, x, z)
    g.roads = g.roads.filter(function (o) { return o.id !== roadId })
    g.roads.push({ id: g.nextId++, a: r.a, b: n.id, lanes: r.lanes })
    g.roads.push({ id: g.nextId++, a: n.id, b: r.b, lanes: r.lanes })
    return n.id
}

// Resolve one end of a new road to a node id, joining or splitting whatever is
// already there. This is what makes "roads connect to other roads" the default
// rather than something the user has to aim for.
function _resolveEnd(g, x, z, snapNode, snapRoad) {
    var n = nearestNode(g, x, z, snapNode)
    if (n) return n.id
    var hit = nearestRoad(g, x, z, snapRoad)
    if (hit) return splitRoad(g, hit.road.id, hit.x, hit.z)
    return addNode(g, x, z).id
}

// Proper crossing of two segments: returns { t, u, x, z } for strictly
// interior intersections only. Roads that merely touch at a shared node are
// not crossings - they are already joined.
function _segCross(ax, az, bx, bz, cx, cz, dx, dz) {
    var r1x = bx - ax, r1z = bz - az
    var r2x = dx - cx, r2z = dz - cz
    var den = r1x * r2z - r1z * r2x
    if (Math.abs(den) < 1e-9) return null          // parallel or collinear
    var t = ((cx - ax) * r2z - (cz - az) * r2x) / den
    var u = ((cx - ax) * r1z - (cz - az) * r1x) / den
    var eps = 1e-4
    if (t <= eps || t >= 1 - eps || u <= eps || u >= 1 - eps) return null
    return { t: t, u: u, x: ax + t * r1x, z: az + t * r1z }
}

/*
   Insert a road between two world points and keep the graph planar.

   Both ends join an existing node, split an existing road, or become a new
   node; then every road the new segment crosses is split at the crossing and
   the new road is laid down as a CHAIN through those crossings. The result is
   that dragging one long road across a city gives you a row of proper
   intersections, which is exactly what a learner expects to happen.

   Returns { ok, roads: [ids], nodes: [ids], reason } - reason explains a
   refusal ("short" / "degenerate") so the lab can say why nothing appeared.
*/
function insertRoad(g, x1, z1, x2, z2, opts) {
    opts = opts || {}
    var lanes = opts.lanes || 1
    var snapNode = opts.snapNode === undefined ? SNAP_NODE : opts.snapNode
    var snapRoad = opts.snapRoad === undefined ? SNAP_ROAD : opts.snapRoad

    if (Math.hypot(x2 - x1, z2 - z1) < MIN_LEN)
        return { ok: false, roads: [], nodes: [], reason: "short" }

    var aId = _resolveEnd(g, x1, z1, snapNode, snapRoad)
    var bId = _resolveEnd(g, x2, z2, snapNode, snapRoad)
    if (aId === bId || aId === -1 || bId === -1)
        return { ok: false, roads: [], nodes: [], reason: "degenerate" }

    var A = nodeById(g, aId), B = nodeById(g, bId)

    // Crossings are computed against a SNAPSHOT: splitting does not move any
    // geometry, so the points stay valid while the road list changes under us.
    var snapshot = g.roads.slice()
    var cuts = []
    for (var i = 0; i < snapshot.length; ++i) {
        var r = snapshot[i]
        if (r.a === aId || r.b === aId || r.a === bId || r.b === bId) continue
        var p = nodeById(g, r.a), q = nodeById(g, r.b)
        if (!p || !q) continue
        var hit = _segCross(A.x, A.z, B.x, B.z, p.x, p.z, q.x, q.z)
        if (hit) cuts.push({ t: hit.t, x: hit.x, z: hit.z, roadId: r.id })
    }
    cuts.sort(function (m, n) { return m.t - n.t })

    // Walk the crossings in order, splitting as we go and collecting the chain
    // of nodes the new road threads through.
    var chain = [aId]
    for (var c = 0; c < cuts.length; ++c) {
        var cut = cuts[c]
        var prev = chain[chain.length - 1]
        var pn = nodeById(g, prev)
        if (pn && Math.hypot(pn.x - cut.x, pn.z - cut.z) < MERGE_EPS) continue
        // an earlier cut may already have split this road; re-find the piece
        // that actually contains the point
        var target = roadById(g, cut.roadId)
        var nid = -1
        if (target) {
            nid = splitRoad(g, target.id, cut.x, cut.z)
        } else {
            var near = nearestRoad(g, cut.x, cut.z, MERGE_EPS)
            if (near) nid = splitRoad(g, near.road.id, cut.x, cut.z)
        }
        if (nid !== -1 && chain.indexOf(nid) === -1) chain.push(nid)
    }
    if (chain[chain.length - 1] !== bId) chain.push(bId)

    var made = []
    for (var k = 0; k + 1 < chain.length; ++k) {
        var u = chain[k], v = chain[k + 1]
        if (u === v || _hasRoad(g, u, v)) continue
        var road = { id: g.nextId++, a: u, b: v, lanes: lanes }
        g.roads.push(road)
        made.push(road.id)
    }
    return { ok: made.length > 0, roads: made, nodes: chain,
             reason: made.length ? "" : "degenerate" }
}

function _hasRoad(g, u, v) {
    for (var i = 0; i < g.roads.length; ++i) {
        var r = g.roads[i]
        if ((r.a === u && r.b === v) || (r.a === v && r.b === u)) return true
    }
    return false
}

// Removing a road takes its now-pointless endpoints with it. A node that keeps
// exactly two collinear roads is NOT merged back: the user placed it, and a
// bend they built should stay a bend they can see.
function removeRoad(g, roadId) {
    var r = roadById(g, roadId)
    if (!r) return false
    g.roads = g.roads.filter(function (o) { return o.id !== roadId })
    pruneOrphans(g)
    return true
}

function removeNode(g, nodeId) {
    g.roads = g.roads.filter(function (r) {
        return r.a !== nodeId && r.b !== nodeId
    })
    g.nodes = g.nodes.filter(function (n) { return n.id !== nodeId })
    pruneOrphans(g)
    return true
}

function pruneOrphans(g) {
    var used = {}
    for (var i = 0; i < g.roads.length; ++i) {
        used[g.roads[i].a] = true
        used[g.roads[i].b] = true
    }
    g.nodes = g.nodes.filter(function (n) { return used[n.id] === true })
}

function setLanes(g, roadId, lanes) {
    var r = roadById(g, roadId)
    if (!r) return false
    r.lanes = Math.max(1, Math.min(2, Math.round(lanes)))
    return true
}

// Bounds of everything built, for framing the camera and fitting the map view.
function bounds(g) {
    if (!g.nodes.length) return { x0: -10, x1: 10, z0: -10, z1: 10, empty: true }
    var x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity
    for (var i = 0; i < g.nodes.length; ++i) {
        var n = g.nodes[i]
        x0 = Math.min(x0, n.x); x1 = Math.max(x1, n.x)
        z0 = Math.min(z0, n.z); z1 = Math.max(z1, n.z)
    }
    return { x0: x0, x1: x1, z0: z0, z1: z1, empty: false }
}

// Total centerline length - the denominator behind "how dense is the traffic".
function totalLength(g) {
    var sum = 0
    for (var i = 0; i < g.roads.length; ++i) sum += roadLength(g, g.roads[i])
    return sum
}
