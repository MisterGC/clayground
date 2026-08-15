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
//
// There is none here: the pseudorange fix lives in trilateration.js, which
// solves the same normal equations for both sensors in this kit - ranges plus
// one nuisance unknown, clock for GPS and heading for lidar - and reports a
// covariance in metres rather than a bare DOP. GpsSensor.qml calls
// `Tri.solve(..., {clockUnknown: true})`; this file supplies it the sky.
