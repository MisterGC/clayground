// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Schematic GNSS: a constellation, line-of-sight against the world's blockers,
// pseudoranges and a least-squares fix. The point is that the position error is
// PRODUCED by satellite geometry rather than dialled in.
//
// Stated simplifications (see the lab's paper):
//  - 2D world: the unknowns are x, y and the receiver clock offset, so THREE
//    visible satellites are the minimum here (real GPS needs four, because it
//    also solves z).
//  - Satellites sit a few tens of units up instead of 20 200 km. Real geometry
//    varies mildly; at this scale it varies strongly, which is exactly what
//    makes the effect visible in a classroom.
//  - Ionosphere, troposphere and multipath are not modelled. What is modelled:
//    blockage, geometry (DOP) and per-range noise.

// --- constellation -------------------------------------------------------

// Deterministic drifting constellation: satellite i sits at a fixed elevation
// and drifts in azimuth at its own slow rate. Time-driven, never RNG-driven,
// so it never disturbs the lab's seeded stream.
function constellation(t, count, radius) {
    var sats = []
    for (var i = 0; i < count; ++i) {
        var elev = 22 + 52 * ((i * 7 % count) / Math.max(1, count - 1))   // 22..74 deg
        var az = (i * 360 / count + t * (1.1 + 0.35 * (i % 3))) * Math.PI / 180
        var e = elev * Math.PI / 180
        sats.push({
            id: i,
            x: radius * Math.cos(e) * Math.sin(az),
            y: radius * Math.sin(e),
            z: radius * Math.cos(e) * Math.cos(az),
            elevation: elev
        })
    }
    return sats
}

// --- line of sight -------------------------------------------------------

// Slab test of the segment (from -> to) against an axis-aligned box.
function segmentHitsBox(from, to, box) {
    var dx = to.x - from.x, dy = to.y - from.y, dz = to.z - from.z
    var tmin = 0, tmax = 1
    var axes = [[from.x, dx, box.minx, box.maxx],
                [from.y, dy, box.miny, box.maxy],
                [from.z, dz, box.minz, box.maxz]]
    for (var i = 0; i < 3; ++i) {
        var o = axes[i][0], d = axes[i][1], lo = axes[i][2], hi = axes[i][3]
        if (Math.abs(d) < 1e-9) {
            if (o < lo || o > hi) return false
        } else {
            var t1 = (lo - o) / d, t2 = (hi - o) / d
            if (t1 > t2) { var s = t1; t1 = t2; t2 = s }
            tmin = Math.max(tmin, t1)
            tmax = Math.min(tmax, t2)
            if (tmin > tmax) return false
        }
    }
    return true
}

// Which satellites the receiver can actually see from `rx`.
function visibility(rx, sats, blockers) {
    var out = []
    for (var i = 0; i < sats.length; ++i) {
        var blocked = false
        for (var b = 0; b < blockers.length && !blocked; ++b)
            if (segmentHitsBox(rx, sats[i], blockers[b])) blocked = true
        out.push({ sat: sats[i], visible: !blocked })
    }
    return out
}

// --- the fix -------------------------------------------------------------

function _dist(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
    return Math.sqrt(dx * dx + dy * dy + dz * dz)
}

// Gauss-Newton least squares for (x, z, clockBias) from pseudoranges.
// `rx0` is the starting guess (the previous fix keeps it stable and cheap).
// Returns {x, z, bias, hdop, iterations} or null if the geometry is singular.
function solveFix(sats, ranges, rx0, y) {
    var n = sats.length
    if (n < 3) return null
    var x = rx0.x, z = rx0.z, b = rx0.bias || 0
    var G = [], hdop = 0
    for (var it = 0; it < 6; ++it) {
        // normal equations for the 3 unknowns
        var N = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
        var rhs = [0, 0, 0]
        G = []
        for (var i = 0; i < n; ++i) {
            var p = { x: x, y: y, z: z }
            var d = _dist(p, sats[i])
            if (d < 1e-6) return null
            // row of the geometry matrix: unit vector receiver->satellite, plus
            // the clock column (always 1 - the bias hits every range equally)
            var gx = (x - sats[i].x) / d
            var gz = (z - sats[i].z) / d
            var row = [gx, gz, 1]
            G.push(row)
            var resid = ranges[i] - (d + b)
            for (var r = 0; r < 3; ++r) {
                rhs[r] += row[r] * resid
                for (var c = 0; c < 3; ++c) N[r][c] += row[r] * row[c]
            }
        }
        var step = _solve3(N, rhs)
        if (!step) return null
        x += step[0]; z += step[1]; b += step[2]
        if (Math.abs(step[0]) + Math.abs(step[1]) + Math.abs(step[2]) < 1e-6) break
    }
    // covariance of the solution = sigma^2 * (G^T G)^-1; its position trace is
    // the dilution of precision - geometry turned into a number
    var NtN = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
    for (var k = 0; k < G.length; ++k)
        for (var rr = 0; rr < 3; ++rr)
            for (var cc = 0; cc < 3; ++cc) NtN[rr][cc] += G[k][rr] * G[k][cc]
    var inv = _invert3(NtN)
    hdop = inv ? Math.sqrt(Math.max(0, inv[0][0] + inv[1][1])) : 99
    return { x: x, z: z, bias: b, hdop: hdop }
}

function _solve3(A, rhs) {
    var inv = _invert3(A)
    if (!inv) return null
    return [inv[0][0] * rhs[0] + inv[0][1] * rhs[1] + inv[0][2] * rhs[2],
            inv[1][0] * rhs[0] + inv[1][1] * rhs[1] + inv[1][2] * rhs[2],
            inv[2][0] * rhs[0] + inv[2][1] * rhs[1] + inv[2][2] * rhs[2]]
}

function _invert3(m) {
    var a = m[0][0], b = m[0][1], c = m[0][2]
    var d = m[1][0], e = m[1][1], f = m[1][2]
    var g = m[2][0], h = m[2][1], i = m[2][2]
    var det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    if (Math.abs(det) < 1e-12) return null
    var id = 1 / det
    return [[(e * i - f * h) * id, (c * h - b * i) * id, (b * f - c * e) * id],
            [(f * g - d * i) * id, (a * i - c * g) * id, (c * d - a * f) * id],
            [(d * h - e * g) * id, (b * g - a * h) * id, (a * e - b * d) * id]]
}
