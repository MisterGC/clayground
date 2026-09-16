// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The board: what every build-type lab does with a grid of typed parts that
// carry terminals and are joined by wires - and nothing a domain would
// recognise as its own. Pure JS, so a node suite can check it in a second
// (board.test.js). The QML Board wraps this with state and signals.
//
// A part is { id, type, col, row, rot, ...fields } on a fractional cell grid.
// Everything the board needs to know about a TYPE is in the spec the domain
// kit hands over:
//
//   spec[type] = {
//       terminals: [{x, y}, ...],  // pad offsets in the part's own frame
//                                  // (y runs along the board's z axis)
//       half:      {x, y},         // body footprint half-extents
//       actuator:  {x, y} | null,  // the operable region, tested first
//       keepOut:   1.62,           // cells of clearance; derived from `half` when absent
//       fields:    {...},          // domain state and its defaults
//       rows:      [...],          // card rows the domain offers
//       watch:     true            // false: no plot / tag rows on the card
//   }
//
// "junction" is reserved: one terminal at the origin and a dot's footprint.
// Tapping a wire drops one and splits the wire. A domain may still override
// its fields (the circuit kit gives it the same field set as every part).

var JUNCTION = {
    terminals: [{ x: 0, y: 0 }],
    half: { x: 2.3, y: 2.3 },
    actuator: null,
    fields: {},
    rows: [],
    watch: false
}

// Two pads in a line, the shape most parts have - what a type without a
// spec entry gets, so a stub domain can start with one line of spec.
var DEFAULT = {
    terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }],
    half: { x: 4.6, y: 3.4 },
    actuator: null,
    fields: {},
    rows: [],
    watch: true
}

function specOf(spec, type) {
    var s = spec ? spec[type] : undefined
    if (s) return s
    return type === "junction" ? JUNCTION : DEFAULT
}

// --- grid -------------------------------------------------------------------
// g = { cols, rows, cell }: the raster is centred on the origin.
function cellX(g, col) { return (col - (g.cols - 1) / 2) * g.cell }
function cellZ(g, row) { return (row - (g.rows - 1) / 2) * g.cell }
function colOf(g, x) { return x / g.cell + (g.cols - 1) / 2 }
function rowOf(g, z) { return z / g.cell + (g.rows - 1) / 2 }

// --- terminals ----------------------------------------------------------------
function terminalCount(spec, type) { return specOf(spec, type).terminals.length }

function terminalLocal(spec, type, ti) {
    var t = specOf(spec, type).terminals
    var l = t[ti]
    return l ? { x: l.x, y: l.y } : { x: 0, y: 0 }
}

// Turned by the part's yaw. Qt rotates about y counter-clockwise seen from
// above, which for a local (x, z) is x' = x*cos + z*sin, z' = -x*sin + z*cos.
function rotated(l, rot) {
    var a = (rot || 0) * Math.PI / 180
    var c = Math.cos(a), s = Math.sin(a)
    return { x: l.x * c + l.y * s, z: -l.x * s + l.y * c }
}

function terminalPos(spec, g, part, ti) {
    var r = rotated(terminalLocal(spec, part.type, ti), part.rot)
    return { x: cellX(g, part.col) + r.x, z: cellZ(g, part.row) + r.z }
}

// Which way a lead LEAVES its pad, in world x/z: the dominant axis of the
// pad's own offset, turned with the part. Rounded, because cos(90 deg) is
// 6e-17 and a lead that is a hair off axis is not on an axis. Null for a pad
// at the part's centre (a junction has no side).
function terminalDir(spec, part, ti) {
    var l = terminalLocal(spec, part.type, ti)
    if (Math.abs(l.x) < 1e-6 && Math.abs(l.y) < 1e-6) return null
    var lx = 0, lz = 0
    if (Math.abs(l.x) >= Math.abs(l.y)) lx = Math.sign(l.x)
    else lz = Math.sign(l.y)
    var a = (part.rot || 0) * Math.PI / 180
    var c = Math.round(Math.cos(a)), s = Math.round(Math.sin(a))
    return { x: lx * c + lz * s, z: -lx * s + lz * c }
}

// --- footprints ---------------------------------------------------------------
function bodyHalf(spec, type) { var h = specOf(spec, type).half; return { x: h.x, y: h.y } }
function actuatorHalf(spec, type) {
    var a = specOf(spec, type).actuator
    return a ? { x: a.x, y: a.y } : null
}
// Clearance around a part, in cells. Derived from the footprint unless the
// spec says otherwise, so the keep-out and the body cannot drift apart: a
// part reaches its half-extent plus most of a cell, and a solder dot needs
// only the cell it is on.
function keepOut(spec, g, type) {
    var s = specOf(spec, type)
    if (s.keepOut !== undefined) return s.keepOut
    if (type === "junction") return 0.7
    var h = s.half
    return Math.max(h.x, h.y) / g.cell + 0.7
}

// The axis-aligned bound of a body box turned by the part's yaw.
function aabbHalf(half, rot) {
    var a = (rot || 0) * Math.PI / 180
    var c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a))
    return { hx: half.x * c + half.y * s, hz: half.x * s + half.y * c }
}

function inBox(wx, wz, cx, cz, half, rot) {
    var h = aabbHalf(half, rot)
    return Math.abs(cx - wx) < h.hx && Math.abs(cz - wz) < h.hz
}

// --- paths --------------------------------------------------------------------
// A wire's drawn path is a polyline of {x, z}. These two are what the hit test
// and the value labels need of it; a router (the circuit kit's route.js) may
// supply richer paths, the board only walks them.
function closestOnPath(path, x, z) {
    var best = { x: x, z: z, dist: Infinity, index: -1, t: 0 }
    if (!path || path.length === 0) return best
    if (path.length === 1) {
        return { x: path[0].x, z: path[0].z, index: 0, t: 0,
                 dist: Math.hypot(path[0].x - x, path[0].z - z) }
    }
    for (var i = 0; i + 1 < path.length; ++i) {
        var ax = path[i].x, az = path[i].z, bx = path[i + 1].x, bz = path[i + 1].z
        var dx = bx - ax, dz = bz - az
        var len2 = dx * dx + dz * dz
        var t = len2 < 1e-12 ? 0
              : Math.max(0, Math.min(1, ((x - ax) * dx + (z - az) * dz) / len2))
        var px = ax + t * dx, pz = az + t * dz
        var d = Math.hypot(px - x, pz - z)
        if (d < best.dist) best = { x: px, z: pz, dist: d, index: i, t: t }
    }
    return best
}

// Half the path's LENGTH along it - where a reading belongs.
function midOfPath(path) {
    if (!path || path.length === 0) return { x: 0, z: 0 }
    if (path.length === 1) return { x: path[0].x, z: path[0].z }
    var total = 0
    for (var i = 0; i + 1 < path.length; ++i)
        total += Math.hypot(path[i + 1].x - path[i].x, path[i + 1].z - path[i].z)
    var half = total / 2, run = 0
    for (var j = 0; j + 1 < path.length; ++j) {
        var seg = Math.hypot(path[j + 1].x - path[j].x, path[j + 1].z - path[j].z)
        if (run + seg >= half) {
            var t = seg < 1e-12 ? 0 : (half - run) / seg
            return { x: path[j].x + (path[j + 1].x - path[j].x) * t,
                     z: path[j].z + (path[j + 1].z - path[j].z) * t }
        }
        run += seg
    }
    var l = path[path.length - 1]
    return { x: l.x, z: l.z }
}

function straightPath(a, b) { return [{ x: a.x, z: a.z }, { x: b.x, z: b.z }] }

// --- hit testing ----------------------------------------------------------------
// In this order, and the order is the whole point: what you can OPERATE wins
// over what you can wire to, pads win over the body they sit in, and a wire
// is grabbed anywhere along its DRAWN path - the straight line between the
// pads would put a click target where no wire is drawn.
var TERMINAL_RADIUS = 2.3
var WIRE_RADIUS = 1.3

function partById(parts, id) {
    for (var i = 0; i < parts.length; ++i) if (parts[i].id === id) return parts[i]
    return null
}

function hitAt(spec, g, parts, wires, wx, wz, pathOf) {
    var i, el
    for (i = 0; i < parts.length; ++i) {
        el = parts[i]
        var ah = actuatorHalf(spec, el.type)
        if (!ah) continue
        if (inBox(wx, wz, cellX(g, el.col), cellZ(g, el.row), ah, el.rot))
            return { kind: "actuator", el: el.id, type: el.type }
    }
    for (i = 0; i < parts.length; ++i) {
        el = parts[i]
        var n = terminalCount(spec, el.type)
        for (var ti = 0; ti < n; ++ti) {
            var p = terminalPos(spec, g, el, ti)
            if (Math.hypot(p.x - wx, p.z - wz) < TERMINAL_RADIUS)
                return { kind: "terminal", el: el.id, ti: ti }
        }
    }
    for (i = 0; i < parts.length; ++i) {
        el = parts[i]
        if (el.type === "junction") continue   // handled as a terminal
        if (inBox(wx, wz, cellX(g, el.col), cellZ(g, el.row), bodyHalf(spec, el.type), el.rot))
            return { kind: "element", el: el.id, type: el.type }
    }
    for (i = 0; i < wires.length; ++i) {
        var w = wires[i]
        if (closestOnPath(pathOf(w), wx, wz).dist < WIRE_RADIUS)
            return { kind: "wire", wire: w.id }
    }
    return null
}

// --- placement -------------------------------------------------------------------
function cellFree(spec, g, parts, col, row, ignoreId, type) {
    var need = keepOut(spec, g, type)
    for (var i = 0; i < parts.length; ++i) {
        var el = parts[i]
        if (el.id === ignoreId) continue
        var have = keepOut(spec, g, el.type)
        // a dot needs only its own clearance from anything; between two
        // real parts the larger clearance decides, whichever side it is on
        var k = (type === "junction" || el.type === "junction") ? Math.min(need, have)
                                                                : Math.max(need, have)
        if (Math.abs(el.col - col) < k && Math.abs(el.row - row) < k) return false
    }
    return true
}

// The asked cell, clamped to the board, then the cells around it in growing
// squares - row-major within a square, so two labs asking the same question
// get the same answer.
function nearestFreeCell(spec, g, parts, col, row, type) {
    col = Math.max(0, Math.min(g.cols - 1, Math.round(col)))
    row = Math.max(0, Math.min(g.rows - 1, Math.round(row)))
    for (var radius = 0; radius < g.cols; ++radius)
        for (var dr = -radius; dr <= radius; ++dr)
            for (var dc = -radius; dc <= radius; ++dc) {
                var c = col + dc, r = row + dr
                if (c < 0 || c >= g.cols || r < 0 || r >= g.rows) continue
                if (cellFree(spec, g, parts, c, r, -1, type)) return { col: c, row: r }
            }
    return null
}

// --- parts ----------------------------------------------------------------------
// The field order is the spec's: id, type, col, row, rot first, then the
// domain's fields with their defaults, so a serialized part reads the same
// whichever path made it.
function newPart(spec, id, type, col, row) {
    var p = { id: id, type: type, col: col, row: row, rot: 0 }
    var f = specOf(spec, type).fields || {}
    for (var k in f) p[k] = f[k]
    return p
}

function withDefaults(spec, el) {
    var f = specOf(spec, el.type).fields || {}
    var p = { id: el.id, type: el.type, col: el.col, row: el.row,
              rot: el.rot === undefined ? 0 : el.rot }
    for (var k in f) p[k] = el[k] === undefined ? f[k] : el[k]
    for (var e in el) if (p[e] === undefined) p[e] = el[e]
    return p
}

function toState(parts, wires, nextId) {
    var ps = [], ws = []
    for (var i = 0; i < parts.length; ++i) {
        var c = {}
        for (var k in parts[i]) c[k] = parts[i][k]
        ps.push(c)
    }
    for (var j = 0; j < wires.length; ++j)
        ws.push({ id: wires[j].id, a: wires[j].a.slice(), b: wires[j].b.slice() })
    return { parts: ps, wires: ws, nextId: nextId }
}

function fromState(spec, s) {
    var src = s.parts || s.elements || []
    var ps = [], ws = []
    for (var i = 0; i < src.length; ++i) ps.push(withDefaults(spec, src[i]))
    var wsrc = s.wires || []
    for (var j = 0; j < wsrc.length; ++j)
        ws.push({ id: wsrc[j].id, a: wsrc[j].a.slice(), b: wsrc[j].b.slice() })
    var next = s.nextId
    if (next === undefined) {
        next = 1
        for (var k = 0; k < ps.length; ++k) next = Math.max(next, ps[k].id + 1)
        for (var l = 0; l < ws.length; ++l) next = Math.max(next, ws[l].id + 1)
    }
    return { parts: ps, wires: ws, nextId: next }
}

function sameWire(w, a, b) {
    return (w.a[0] === a[0] && w.a[1] === a[1] && w.b[0] === b[0] && w.b[1] === b[1])
        || (w.a[0] === b[0] && w.a[1] === b[1] && w.b[0] === a[0] && w.b[1] === a[1])
}

// --- for routers -------------------------------------------------------------------
// What a router is handed: every body as an obstacle box, every wire as a
// link between two pads with the side each lead leaves on.
function obstaclesOf(spec, g, parts) {
    var out = []
    for (var i = 0; i < parts.length; ++i) {
        var el = parts[i]
        if (el.type === "junction") continue
        var h = aabbHalf(bodyHalf(spec, el.type), el.rot)
        out.push({ id: el.id, x: cellX(g, el.col), z: cellZ(g, el.row), hx: h.hx, hz: h.hz })
    }
    return out
}

function linksOf(spec, g, parts, wires) {
    var out = []
    for (var i = 0; i < wires.length; ++i) {
        var w = wires[i]
        var pa = partById(parts, w.a[0]), pb = partById(parts, w.b[0])
        if (!pa || !pb) continue
        var a = terminalPos(spec, g, pa, w.a[1]), b = terminalPos(spec, g, pb, w.b[1])
        out.push({ id: w.id,
                   a: { x: a.x, z: a.z, dir: terminalDir(spec, pa, w.a[1]) },
                   b: { x: b.x, z: b.z, dir: terminalDir(spec, pb, w.b[1]) },
                   ends: [w.a[0], w.b[0]] })
    }
    return out
}

// The corner points that frame these parts, padded: a single part is a point
// and a camera needs extent to land on.
function boundsOf(g, parts, pad) {
    var out = []
    for (var i = 0; i < parts.length; ++i) {
        var x = cellX(g, parts[i].col), z = cellZ(g, parts[i].row)
        out.push({ x: x - pad, z: z - pad })
        out.push({ x: x + pad, z: z + pad })
    }
    return out
}
