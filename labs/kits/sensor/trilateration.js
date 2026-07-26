// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Localisation from anchors with KNOWN positions - the shared engine behind
// both localisation sensors in this kit:
//
//   GPS   anchors = satellites, range only, plus one unknown: the receiver
//         clock offset (which is why three anchors is the 2D minimum here).
//   Lidar anchors = mapped landmarks, range AND bearing, no clock unknown -
//         but bearing is only meaningful because the map says WHICH landmark
//         a detection is. Without the map there is nothing to anchor to.
//
// Weighted Gauss-Newton, weights 1/sigma, so the returned covariance is in
// metres^2 and needs no post-scaling. DOP is reported as sigma / sigmaRange:
// the geometry's own contribution, independent of how good the ranging is.

// --- small linear algebra (n <= 3) ---------------------------------------

function invert(m) {
    var n = m.length
    var a = [], i, j, k
    for (i = 0; i < n; ++i) {
        a.push([])
        for (j = 0; j < n; ++j) a[i].push(m[i][j])
        for (j = 0; j < n; ++j) a[i].push(i === j ? 1 : 0)
    }
    for (i = 0; i < n; ++i) {
        var piv = i
        for (k = i + 1; k < n; ++k)
            if (Math.abs(a[k][i]) > Math.abs(a[piv][i])) piv = k
        if (Math.abs(a[piv][i]) < 1e-12) return null      // singular geometry
        var tmp = a[i]; a[i] = a[piv]; a[piv] = tmp
        var d = a[i][i]
        for (j = 0; j < 2 * n; ++j) a[i][j] /= d
        for (k = 0; k < n; ++k) {
            if (k === i) continue
            var f = a[k][i]
            if (f === 0) continue
            for (j = 0; j < 2 * n; ++j) a[k][j] -= f * a[i][j]
        }
    }
    var out = []
    for (i = 0; i < n; ++i) {
        out.push([])
        for (j = 0; j < n; ++j) out[i].push(a[i][n + j])
    }
    return out
}

function _wrapPi(a) {
    while (a > Math.PI) a -= 2 * Math.PI
    while (a < -Math.PI) a += 2 * Math.PI
    return a
}

// --- the solve -----------------------------------------------------------

// anchors : [{x, y, z}] world positions taken from the map / ephemeris
// meas    : [{range, bearing}] - bearing optional, in the sensor's own frame
// opts    : { guess:{x,z,bias}, y, clockUnknown, headingUnknown, heading,
//             sigmaRange, sigmaBearing }
// returns : { x, z, bias, heading, sigma, dop } or null
//
// Beyond x/z there is room for ONE nuisance unknown per sensor, and which one
// it is characterises the sensor:
//   clockUnknown   (GPS)   - a bias common to every range; needs one anchor more
//                            than you would expect (3 for a 2D fix).
//   headingUnknown (lidar) - the sensor's own orientation. Solving it instead of
//                            trusting an external heading is what keeps the fix
//                            unbiased: a borrowed heading that drifts by theta
//                            shows up as a cross-range error of about
//                            range * theta that the covariance never sees.
function solve(anchors, meas, opts) {
    var o = opts || {}
    var extras = []
    if (o.clockUnknown) extras.push("clock")
    if (o.headingUnknown) extras.push("heading")
    var nUnknown = 2 + extras.length
    var sr = o.sigmaRange > 0 ? o.sigmaRange : 1
    var sb = o.sigmaBearing > 0 ? o.sigmaBearing : 0.02
    var heading = o.heading || 0
    var y = o.y || 0

    // count the constraints: every range is one, every bearing another
    var rows = 0
    for (var m = 0; m < meas.length; ++m) {
        rows += 1
        if (meas[m].bearing !== undefined) rows += 1
    }
    if (anchors.length < 1 || rows < nUnknown) return null

    var g = o.guess || {}
    var x = g.x || 0, z = g.z || 0, b = g.bias || 0
    var dh = 0                    // correction to the assumed heading
    var N = null

    for (var it = 0; it < 8; ++it) {
        N = []
        var rhs = []
        for (var r = 0; r < nUnknown; ++r) {
            N.push(new Array(nUnknown).fill(0))
            rhs.push(0)
        }
        for (var i = 0; i < anchors.length; ++i) {
            var a = anchors[i]
            var dx = x - a.x, dz = z - a.z, dy = y - (a.y === undefined ? y : a.y)
            var d = Math.sqrt(dx * dx + dy * dy + dz * dz)
            if (d < 1e-6) return null

            // range row: d(dist)/d(unknowns), weighted by 1/sigmaRange.
            // A clock bias hits every range equally; heading does not enter.
            var row = [dx / d, dz / d]
            for (var e = 0; e < extras.length; ++e)
                row.push(extras[e] === "clock" ? 1 : 0)
            var res = (meas[i].range - (d + b))
            _accumulate(N, rhs, row, res, 1 / sr, nUnknown)

            if (meas[i].bearing !== undefined) {
                // bearing row: the landmark's direction in the sensor frame.
                // Only computable because the map identifies the anchor.
                // Rotating the sensor by dh shifts every bearing by -dh.
                var ax = a.x - x, az = a.z - z
                var rho2 = ax * ax + az * az
                if (rho2 < 1e-9) return null
                var predicted = _wrapPi(Math.atan2(ax, az) - (heading + dh))
                var brow = [-az / rho2, ax / rho2]
                for (var eb = 0; eb < extras.length; ++eb)
                    brow.push(extras[eb] === "heading" ? -1 : 0)
                var bres = _wrapPi(meas[i].bearing - predicted)
                _accumulate(N, rhs, brow, bres, 1 / sb, nUnknown)
            }
        }
        var inv = invert(N)
        if (!inv) return null
        var step = []
        for (var u = 0; u < nUnknown; ++u) {
            var v = 0
            for (var w = 0; w < nUnknown; ++w) v += inv[u][w] * rhs[w]
            step.push(v)
        }
        x += step[0]; z += step[1]
        var mag = Math.abs(step[0]) + Math.abs(step[1])
        for (var ex = 0; ex < extras.length; ++ex) {
            if (extras[ex] === "clock") b += step[2 + ex]
            else dh += step[2 + ex]
            mag += Math.abs(step[2 + ex])
        }
        if (mag < 1e-7) break
    }

    // covariance of the estimate: weights were 1/sigma, so this is in metres^2.
    // Only the position block is reported - the nuisance unknown has been
    // marginalised out by the inversion, which is exactly why solving for it
    // makes sigma tell the truth instead of flattering the fix.
    var cov = invert(N)
    if (!cov) return null
    var sigma = Math.sqrt(Math.max(0, cov[0][0] + cov[1][1]))
    return { x: x, z: z, bias: b, heading: heading + dh,
             sigma: sigma, dop: sigma / sr }
}

// one weighted row into the normal equations
function _accumulate(N, rhs, row, residual, weight, n) {
    var w2 = weight * weight
    for (var r = 0; r < n; ++r) {
        rhs[r] += w2 * row[r] * residual
        for (var c = 0; c < n; ++c) N[r][c] += w2 * row[r] * row[c]
    }
}
