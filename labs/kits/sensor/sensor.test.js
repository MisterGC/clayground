// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the sensor kit's localisation engine and GNSS sky model.
//
//     node labs/kits/sensor/sensor.test.js
//
// trilateration.js and gnss.js are Qt-free (`.pragma library`) precisely so
// they can be checked here, with no running engine. Both sensors in the kit -
// GpsSensor (ranges + clock unknown) and LidarSensor (ranges + bearings +
// heading unknown) - are thin QML wrappers over `trilateration.solve`, so the
// numbers the lab teaches are the numbers asserted below.
//
// What is expensive to get wrong, and therefore what this covers:
//   - the fix converges to the truth from noise-free measurements, which is
//     the only way to tell a solver bug from sensor noise later;
//   - the nuisance unknown (clock / heading) is actually estimated, and the
//     lab's central lesson - a nuisance left UNSOLVED biases the fix while the
//     covariance keeps reporting business as usual - reproduces numerically;
//   - sigma and DOP move the right way as geometry degrades, since those two
//     numbers are the lab's whole point ("error is produced by geometry");
//   - the degenerate cases return null rather than nonsense;
//   - the sky model is deterministic in t and blocks line of sight correctly.
//
// Deliberately deterministic: every input is fixed, nothing reads a clock and
// nothing draws a random number. Measurements are synthesised from a known
// truth by the same model the solver inverts, so a converged fix must return
// that truth to machine precision - the tolerances below are numerical, not
// statistical.

const K = require('../kitcheck.js')

const KIT = process.argv[2] || __dirname
const T = K.load(KIT, 'trilateration.js', ['solve', 'invert'])
const G = K.load(KIT, 'gnss.js', ['constellation', 'segmentHitsBox', 'visibility'])

const ok = K.ok, eq = K.eq, near = K.near, section = K.section

// --- helpers ----------------------------------------------------------------

// Anchors on a ring of radius R at the given azimuths (degrees), optionally
// lifted to height y. Azimuth spread IS the geometry: a wide spread is a good
// fix, a narrow one is the degenerate case the DOP is supposed to expose.
function ring(azimuths, R, y) {
    return azimuths.map(function (a) {
        var rad = a * Math.PI / 180
        return { x: R * Math.sin(rad), y: y || 0, z: R * Math.cos(rad) }
    })
}

// Noise-free pseudoranges from `p` (at height y) to each anchor, plus a
// constant clock bias - exactly the model `solve` inverts.
function rangesTo(anchors, p, y, bias) {
    return anchors.map(function (a) {
        var dx = p.x - a.x, dz = p.z - a.z
        var dy = (a.y === undefined ? 0 : (y || 0) - a.y)
        return { range: Math.sqrt(dx * dx + dy * dy + dz * dz) + (bias || 0) }
    })
}

// Noise-free range AND bearing to each landmark, in a sensor frame rotated by
// `heading`. Mirrors LidarSensor.qml: bearing = atan2(dx, dz) - heading.
function rangeBearingTo(anchors, p, heading) {
    return anchors.map(function (a) {
        var dx = a.x - p.x, dz = a.z - p.z
        return { range: Math.sqrt(dx * dx + dz * dz),
                 bearing: Math.atan2(dx, dz) - heading }
    })
}

function errOf(sol, p) { return Math.hypot(sol.x - p.x, sol.z - p.z) }

// The lab's own geometry scales: anchors tens of units out, receiver near the
// origin but not ON it (a fix that only works at the origin proves nothing).
var TRUTH = { x: 4, z: -7 }
var WIDE = ring([0, 120, 240], 50)

// ---------------------------------------------------------------- convergence
section('trilateration - convergence, ranges only')
{
    var sol = T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 1 })
    ok('three spread anchors give a fix', !!sol)
    near('...that lands on the truth in x', sol.x, TRUTH.x, 1e-9)
    near('...and in z', sol.z, TRUTH.z, 1e-9)
    eq('no clock unknown means no bias is invented', sol.bias, 0)
    eq('no heading unknown means the heading comes back as given', sol.heading, 0)
    ok('sigma is a positive, finite number', sol.sigma > 0 && isFinite(sol.sigma))
}
{
    // The default guess is the origin; the solver must not depend on being
    // started near the answer, because the lab's first fix has no previous one.
    var far = T.solve(WIDE, rangesTo(WIDE, TRUTH),
                      { guess: { x: 200, z: -300 }, sigmaRange: 1 })
    near('a guess 300 units out still converges (x)', far.x, TRUTH.x, 1e-6)
    near('a guess 300 units out still converges (z)', far.z, TRUTH.z, 1e-6)
}
{
    // GPS geometry: anchors far above the receiver, only x/z solved. The
    // vertical leg of every range is what `opts.y` is for - drop it and the
    // horizontal fix is wrong, which is why this is asserted separately.
    var sats = [{ x: -40, y: 50, z: -40 }, { x: 45, y: 60, z: -30 }, { x: 0, y: 55, z: 50 }]
    var sol = T.solve(sats, rangesTo(sats, TRUTH, 1.6), { y: 1.6, sigmaRange: 1 })
    near('anchors above the receiver: x recovered', sol.x, TRUTH.x, 1e-6)
    near('anchors above the receiver: z recovered', sol.z, TRUTH.z, 1e-6)
}
{
    // Two ranges and two unknowns - exactly determined, and genuinely
    // ambiguous: the two circles meet twice, at points mirrored across the
    // line joining the anchors. Gauss-Newton converges to whichever basin the
    // guess sits in, so the guess is what disambiguates - which is why the
    // sensors feed the previous fix back in as the next guess.
    var two = [WIDE[0], WIDE[1]]
    var m = rangesTo(two, TRUTH)
    var near_ = T.solve(two, m, { guess: { x: 3, z: -6 }, sigmaRange: 1 })
    near('two ranges, guess on the right side: x', near_.x, TRUTH.x, 1e-6)
    near('two ranges, guess on the right side: z', near_.z, TRUTH.z, 1e-6)

    // reflect TRUTH across the anchor-anchor line to get the ghost solution
    var ux = two[1].x - two[0].x, uz = two[1].z - two[0].z
    var t = ((TRUTH.x - two[0].x) * ux + (TRUTH.z - two[0].z) * uz) / (ux * ux + uz * uz)
    var GHOST = { x: 2 * (two[0].x + t * ux) - TRUTH.x,
                  z: 2 * (two[0].z + t * uz) - TRUTH.z }
    var mirrored = T.solve(two, m, { guess: { x: GHOST.x + 2, z: GHOST.z + 2 },
                                     sigmaRange: 1 })
    ok('two ranges are ambiguous - a guess in the other basin finds the ghost',
       errOf(mirrored, GHOST) < 1e-6 && errOf(mirrored, TRUTH) > 1)
    near('...and the ghost fits the measurements exactly as well',
         Math.hypot(mirrored.x - two[0].x, mirrored.z - two[0].z),
         m[0].range, 1e-6)
}
{
    // Determinism: paper.md quotes these numbers and the flow's expect
    // predicates assert them, so two identical calls must agree exactly.
    var a = JSON.stringify(T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 1 }))
    var b = JSON.stringify(T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 1 }))
    eq('the same anchors and ranges solve to the same numbers', a, b)
}

// ------------------------------------------------------------------ the clock
section('trilateration - the clock unknown (GPS)')
{
    var BIAS = 12
    var m = rangesTo(WIDE, TRUTH, 0, BIAS)
    var sol = T.solve(WIDE, m, { clockUnknown: true, sigmaRange: 1 })
    near('a common offset on every range is recovered as the bias', sol.bias, BIAS, 1e-9)
    near('...leaving x unbiased', sol.x, TRUTH.x, 1e-9)
    near('...and z unbiased', sol.z, TRUTH.z, 1e-9)

    // The lesson: the same measurements, with the clock NOT solved for, put
    // the receiver somewhere else entirely - the bias is absorbed into position.
    var naive = T.solve(WIDE, m, { sigmaRange: 1 })
    ok('the same ranges with the clock ignored land metres away',
       errOf(naive, TRUTH) > 1)
    ok('...while sigma barely notices, so the fix looks healthy',
       naive.sigma < 2 * sol.sigma)
}
{
    // Three unknowns need three rows: three satellites is the 2D minimum here,
    // one more than the two a bias-free receiver would need.
    var two = [WIDE[0], WIDE[1]]
    eq('two ranges cannot support a clock unknown',
       T.solve(two, rangesTo(two, TRUTH, 0, 12), { clockUnknown: true, sigmaRange: 1 }),
       null)
    ok('three can',
       !!T.solve(WIDE, rangesTo(WIDE, TRUTH, 0, 12), { clockUnknown: true, sigmaRange: 1 }))
}
{
    // A bias that is KNOWN can be handed in through the guess and is simply
    // subtracted; with clockUnknown off it is never re-estimated.
    var sol = T.solve(WIDE, rangesTo(WIDE, TRUTH, 0, 9),
                      { guess: { x: 0, z: 0, bias: 9 }, sigmaRange: 1 })
    near('a known bias passed through the guess is honoured (x)', sol.x, TRUTH.x, 1e-6)
    near('...and (z)', sol.z, TRUTH.z, 1e-6)
    eq('...and comes back unchanged', sol.bias, 9)
}

// ---------------------------------------------------------------- the heading
section('trilateration - the heading unknown (lidar)')
{
    var LM = [{ x: -20, y: 0, z: 10 }, { x: 25, y: 0, z: -5 }, { x: 5, y: 0, z: 40 }]
    var H = 0.6
    var meas = rangeBearingTo(LM, TRUTH, H)

    var sol = T.solve(LM, meas, { guess: { x: 0, z: 0 }, heading: 0,
                                  headingUnknown: true,
                                  sigmaRange: 0.1, sigmaBearing: 0.01 })
    near('heading is recovered from bearings alone', sol.heading, H, 1e-9)
    near('...with x on the truth', sol.x, TRUTH.x, 1e-9)
    near('...and z on the truth', sol.z, TRUTH.z, 1e-9)

    // The trap the kit exists to teach, reproduced numerically. Ranges loose,
    // bearings tight, so the bearings drive the fix: a heading borrowed from
    // drifting odometry and TRUSTED biases the position by about range*error,
    // while sigma - which only sees the residual geometry - stays small.
    var HERR = 0.10
    var trusted = T.solve(LM, meas, { guess: TRUTH, heading: H + HERR,
                                      headingUnknown: false,
                                      sigmaRange: 5, sigmaBearing: 0.005 })
    var solved = T.solve(LM, meas, { guess: TRUTH, heading: H + HERR,
                                     headingUnknown: true,
                                     sigmaRange: 5, sigmaBearing: 0.005 })
    ok('a trusted heading that is 0.1 rad off biases the fix by metres',
       errOf(trusted, TRUTH) > 3)

    // The bias is a lever arm: it grows in proportion to the heading error,
    // which is what makes a slowly drifting odometry heading so corrosive.
    var half = T.solve(LM, meas, { guess: TRUTH, heading: H + HERR / 2,
                                   headingUnknown: false,
                                   sigmaRange: 5, sigmaBearing: 0.005 })
    near('...growing linearly with that error, not abruptly',
         errOf(trusted, TRUTH) / errOf(half, TRUTH), 2, 0.05)

    ok('...and the covariance never sees it - error far exceeds sigma',
       errOf(trusted, TRUTH) > 10 * trusted.sigma)
    ok('solving for the heading instead removes the bias entirely',
       errOf(solved, TRUTH) < 1e-9)
    ok('...at the honest price of a larger sigma', solved.sigma > trusted.sigma)
    near('...and it reports the true heading, not the borrowed one',
         solved.heading, H, 1e-9)
}
{
    // Bearings wrap; the residual must be wrapped too or a landmark behind the
    // sensor drags the solution round the circle. Every heading below puts at
    // least one bearing near +-pi.
    var BACK = [{ x: 4, y: 0, z: -60 }, { x: -30, y: 0, z: -30 }, { x: 30, y: 0, z: -25 }]
    var headings = [0, 3.1, -3.1, 1.5707963267948966]
    for (var i = 0; i < headings.length; ++i) {
        var h = headings[i]
        var s = T.solve(BACK, rangeBearingTo(BACK, TRUTH, h),
                        { guess: { x: 0, z: 0 }, heading: h, headingUnknown: true,
                          sigmaRange: 0.1, sigmaBearing: 0.01 })
        ok('bearings wrapping at +-pi still converge (heading ' + h + ')',
           s && errOf(s, TRUTH) < 1e-6)
        near('...and the heading comes back (heading ' + h + ')', s.heading, h, 1e-9)
    }

    // The returned heading is wrapped: converging from a guess a full half
    // turn out must report ~0, not 2*pi - a consumer comparing against a
    // wrapped truth would otherwise see a phantom full-circle error.
    var FRONT = [{ x: 4, y: 0, z: 60 }, { x: -30, y: 0, z: 30 }, { x: 30, y: 0, z: 25 }]
    var wrapped = T.solve(FRONT, rangeBearingTo(FRONT, TRUTH, 0),
                          { guess: { x: 0, z: 0 }, heading: Math.PI,
                            headingUnknown: true,
                            sigmaRange: 0.1, sigmaBearing: 0.01 })
    ok('a solve started half a turn off reports the wrapped heading',
       wrapped !== null && Math.abs(wrapped.heading) < 1e-6)
}
{
    // Row counting with bearings: each bearing is a second constraint, so two
    // landmarks (4 rows) can carry the heading unknown but one (2 rows) cannot.
    var LM = [{ x: -20, y: 0, z: 10 }, { x: 25, y: 0, z: -5 }]
    var ONE = [LM[0]]
    ok('two landmarks with bearings support the heading unknown',
       !!T.solve(LM, rangeBearingTo(LM, TRUTH, 0.6),
                 { guess: TRUTH, heading: 0.6, headingUnknown: true,
                   sigmaRange: 0.1, sigmaBearing: 0.01 }))
    eq('one landmark does not - two rows cannot carry three unknowns',
       T.solve(ONE, rangeBearingTo(ONE, TRUTH, 0.6),
               { guess: TRUTH, heading: 0.6, headingUnknown: true,
                 sigmaRange: 0.1, sigmaBearing: 0.01 }),
       null)
    ok('but one landmark with a KNOWN heading pins x and z exactly',
       !!T.solve(ONE, rangeBearingTo(ONE, TRUTH, 0.6),
                 { guess: TRUTH, heading: 0.6,
                   sigmaRange: 0.1, sigmaBearing: 0.01 }))
}

// ----------------------------------------------------------------- geometry
section('trilateration - sigma and DOP follow the geometry')
{
    // The kit's headline claim: error is PRODUCED by geometry. Squeeze the
    // anchors into an ever narrower slice of sky and the DOP must climb
    // monotonically, even though every measurement stays exact.
    var spreads = [[0, 120, 240], [0, 50, 100], [0, 25, 50], [0, 12, 24], [0, 6, 12]]
    var prev = 0
    var monotone = true
    var dops = []
    for (var i = 0; i < spreads.length; ++i) {
        var A = ring(spreads[i], 50)
        var s = T.solve(A, rangesTo(A, TRUTH), { guess: TRUTH, sigmaRange: 1 })
        dops.push(s.dop)
        if (i > 0 && !(s.dop > prev)) monotone = false
        prev = s.dop
    }
    ok('DOP grows monotonically as the anchors crowd together', monotone,
       dops.map(function (d) { return d.toFixed(2) }).join(' -> '))
    ok('a well-spread ring is near the theoretical floor', dops[0] < 1.2)
    ok('a 12-degree sliver is more than five times worse', dops[4] > 5 * dops[0])

    // Exactly collinear anchors with the receiver ON the line: the normal
    // matrix is singular and there is no fix to report.
    var line = [{ x: -30, y: 0, z: 0 }, { x: 0, y: 0, z: 0 }, { x: 30, y: 0, z: 0 }]
    eq('perfectly collinear anchors are singular, not merely bad',
       T.solve(line, rangesTo(line, { x: 4, z: -7 }), { sigmaRange: 1 }), null)
}
{
    // DOP is defined as sigma / sigmaRange, i.e. the geometry's own
    // contribution. Ten times noisier ranging must move sigma and leave DOP be.
    var s1 = T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 1 })
    var s10 = T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 10 })
    near('sigma scales linearly with the ranging sigma', s10.sigma, 10 * s1.sigma, 1e-6)
    near('DOP is independent of it - it is geometry alone', s10.dop, s1.dop, 1e-9)
    near('a non-positive sigmaRange falls back to 1',
         T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 0 }).sigma, s1.sigma, 1e-12)
}
{
    // More anchors, same quality of ranging: the fix must get tighter.
    var four = WIDE.concat(ring([60], 50))
    var s3 = T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 1 })
    var s4 = T.solve(four, rangesTo(four, TRUTH), { sigmaRange: 1 })
    ok('a fourth anchor tightens sigma', s4.sigma < s3.sigma)
}
{
    // Solving the clock costs geometry: the same narrowing that merely doubles
    // a bias-free DOP multiplies the GPS one, because the clock column is
    // nearly parallel to the range rows when the sky is a slit.
    var wide = ring([0, 90, 180, 270], 80, 40)
    var slit = ring([0, 8, 16, 24], 80, 40)
    var w = T.solve(wide, rangesTo(wide, TRUTH, 1.6, 7),
                    { guess: TRUTH, y: 1.6, clockUnknown: true, sigmaRange: 1 })
    var n = T.solve(slit, rangesTo(slit, TRUTH, 1.6, 7),
                    { guess: TRUTH, y: 1.6, clockUnknown: true, sigmaRange: 1 })
    near('the wide sky still nails the bias', w.bias, 7, 1e-6)
    near('...and so does the slit, given exact ranges', n.bias, 7, 1e-6)
    ok('but the slit costs an order of magnitude in DOP', n.dop > 10 * w.dop)
}

// --------------------------------------------------------------- robustness
section('trilateration - degenerate input')
{
    eq('no anchors at all', T.solve([], [], { sigmaRange: 1 }), null)
    eq('one range cannot fix two unknowns',
       T.solve([WIDE[0]], rangesTo([WIDE[0]], TRUTH), { sigmaRange: 1 }), null)
    eq('the receiver sitting exactly on an anchor',
       T.solve(WIDE, rangesTo(WIDE, { x: WIDE[0].x, z: WIDE[0].z }),
               { guess: { x: WIDE[0].x, z: WIDE[0].z }, sigmaRange: 1 }),
       null)

    // A poisoned measurement rides through the normal equations without ever
    // failing the inversion, so the solver guards its own return: a fix a
    // caller cannot trust is null, never a number-shaped lie - which is what
    // lets the sensors' plain `if (!sol)` check skip the epoch.
    var poisoned = rangesTo(WIDE, TRUTH)
    poisoned[1].range = NaN
    eq('a NaN range yields null, not a NaN fix',
       T.solve(WIDE, poisoned, { sigmaRange: 1 }), null)
}
{
    // The nuisance unknown is optional in both directions and never invents
    // itself: with neither flag the returned bias and heading are the inputs.
    var sol = T.solve(WIDE, rangesTo(WIDE, TRUTH), { sigmaRange: 1, heading: 1.23 })
    eq('an unsolved heading is returned exactly as supplied', sol.heading, 1.23)
}

// ------------------------------------------------------------ the linear algebra
section('trilateration - the inverse it is built on')
{
    var I = T.invert([[1, 0], [0, 1]])
    eq('identity inverts to identity', JSON.stringify(I), JSON.stringify([[1, 0], [0, 1]]))
    var M = [[4, 7], [2, 6]]
    var Mi = T.invert(M)
    near('2x2 inverse, entry 00', Mi[0][0], 0.6, 1e-12)
    near('2x2 inverse, entry 01', Mi[0][1], -0.7, 1e-12)
    near('2x2 inverse, entry 10', Mi[1][0], -0.2, 1e-12)
    near('2x2 inverse, entry 11', Mi[1][1], 0.4, 1e-12)
    eq('a singular matrix inverts to null', T.invert([[1, 2], [2, 4]]), null)
    // Pivoting: a zero in the leading position must be swapped away, not
    // divided by. Without the pivot search this returns null.
    ok('a zero pivot is swapped, not divided by', !!T.invert([[0, 1], [1, 0]]))
    var P = T.invert([[0, 1], [1, 0]])
    eq('...and the swap gives the right inverse',
       JSON.stringify(P), JSON.stringify([[0, 1], [1, 0]]))
}

// ------------------------------------------------------------- constellation
section('gnss - the constellation')
{
    var a = G.constellation(3.5, 8, 100)
    var b = G.constellation(3.5, 8, 100)
    eq('the constellation is a pure function of t - no RNG, no clock',
       JSON.stringify(a), JSON.stringify(b))
    eq('it returns the requested count', a.length, 8)
    var ids = a.map(function (s) { return s.id }).join(',')
    eq('ids are 0..n-1 in order', ids, '0,1,2,3,4,5,6,7')

    var onSphere = true, aloft = true, inBand = true
    for (var i = 0; i < a.length; ++i) {
        if (Math.abs(Math.hypot(a[i].x, a[i].y, a[i].z) - 100) > 1e-9) onSphere = false
        if (!(a[i].y > 0)) aloft = false
        if (a[i].elevation < 22 - 1e-9 || a[i].elevation > 74 + 1e-9) inBand = false
    }
    ok('every satellite sits on the sphere of the given radius', onSphere)
    ok('every satellite is above the horizon', aloft)
    ok('elevations stay inside the documented 22..74 degree band', inBand)

    var elevs = a.map(function (s) { return s.elevation })
    near('the band is actually reached at the bottom', Math.min.apply(null, elevs), 22, 1e-9)
    near('...and at the top', Math.max.apply(null, elevs), 74, 1e-9)
}
{
    // Drift is in azimuth only: the sky turns, the elevations do not, which is
    // what makes a run reproducible from t alone.
    var t0 = G.constellation(0, 8, 100)
    var t9 = G.constellation(9.0, 8, 100)
    eq('elevations are constant in t',
       JSON.stringify(t0.map(function (s) { return s.elevation })),
       JSON.stringify(t9.map(function (s) { return s.elevation })))
    var moved = 0
    for (var i = 0; i < 8; ++i)
        if (Math.hypot(t0[i].x - t9[i].x, t0[i].z - t9[i].z) > 1e-6) moved++
    eq('but every satellite has drifted in azimuth', moved, 8)
    var stillOnSphere = t9.every(function (s) {
        return Math.abs(Math.hypot(s.x, s.y, s.z) - 100) < 1e-9
    })
    ok('...without leaving the sphere', stillOnSphere)

    // Rates differ per satellite (1.1 + 0.35 * (i % 3) deg/s), so the pattern
    // is not a rigid rotation - that is what makes geometry change over a run.
    var d0 = Math.atan2(t9[0].x, t9[0].z) - Math.atan2(t0[0].x, t0[0].z)
    var d1 = Math.atan2(t9[1].x, t9[1].z) - Math.atan2(t0[1].x, t0[1].z)
    ok('satellites drift at different rates - the sky is not a rigid turn',
       Math.abs(d0 - d1) > 1e-6)
}
{
    eq('a count of zero is an empty sky, not a crash',
       JSON.stringify(G.constellation(0, 0, 100)), '[]')
    var one = G.constellation(0, 1, 10)
    eq('a single satellite is produced', one.length, 1)
    ok('...with a finite elevation despite the n-1 denominator',
       isFinite(one[0].elevation) && one[0].elevation === 22)
    var negT = G.constellation(-5, 4, 10)
    ok('negative t is as well-defined as positive t',
       negT.length === 4 && negT.every(function (s) { return isFinite(s.x) }))
}

// ------------------------------------------------------------- line of sight
section('gnss - segmentHitsBox')
{
    var BOX = { minx: -5, maxx: 5, miny: 0, maxy: 20, minz: -5, maxz: 5 }
    var lo = { x: 0, y: 1, z: -50 }
    ok('a segment straight through the box hits', G.segmentHitsBox(lo, { x: 0, y: 1, z: 50 }, BOX))
    ok('a parallel segment well to the side misses',
       G.segmentHitsBox({ x: 50, y: 1, z: -50 }, { x: 50, y: 1, z: 50 }, BOX) === false)
    ok('a segment passing high above misses - the y slab is tested too',
       G.segmentHitsBox({ x: 0, y: 99, z: -50 }, { x: 0, y: 99, z: 50 }, BOX) === false)

    // The segment is a segment, not a ray: geometry beyond either endpoint
    // must not block. Getting this wrong makes distant satellites vanish.
    ok('a box beyond the far endpoint does not block',
       G.segmentHitsBox(lo, { x: 0, y: 1, z: -30 }, BOX) === false)
    ok('a box behind the near endpoint does not block',
       G.segmentHitsBox({ x: 0, y: 1, z: 30 }, { x: 0, y: 1, z: 50 }, BOX) === false)
    ok('a segment starting inside the box hits',
       G.segmentHitsBox({ x: 0, y: 1, z: 0 }, { x: 0, y: 1, z: 50 }, BOX))
    ok('an endpoint exactly on the near face counts as a hit',
       G.segmentHitsBox(lo, { x: 0, y: 1, z: -5 }, BOX))
    ok('an endpoint a millimetre short does not',
       G.segmentHitsBox(lo, { x: 0, y: 1, z: -5.001 }, BOX) === false)
    ok('grazing the x=5 face counts as a hit',
       G.segmentHitsBox({ x: 5, y: 1, z: -50 }, { x: 5, y: 1, z: 50 }, BOX))
    ok('a millimetre outside it does not',
       G.segmentHitsBox({ x: 5.001, y: 1, z: -50 }, { x: 5.001, y: 1, z: 50 }, BOX) === false)
    ok('a degenerate zero-length segment inside the box hits',
       G.segmentHitsBox({ x: 0, y: 1, z: 0 }, { x: 0, y: 1, z: 0 }, BOX))
    ok('...and outside it does not',
       G.segmentHitsBox({ x: 50, y: 1, z: 50 }, { x: 50, y: 1, z: 50 }, BOX) === false)
}

section('gnss - visibility')
{
    var RX = { x: 0, y: 1.6, z: 0 }
    var TOWER = { minx: -10, maxx: 10, miny: 0, maxy: 60, minz: 10, maxz: 20 }
    var behind = { x: 0, y: 30, z: 100 }
    var clear = { x: 0, y: 150, z: -100 }

    eq('a satellite behind the tower is blocked',
       G.visibility(RX, [behind], [TOWER])[0].visible, false)
    eq('one in the clear is visible',
       G.visibility(RX, [clear], [TOWER])[0].visible, true)
    eq('with no blockers at all, the same satellite is visible',
       G.visibility(RX, [behind], [])[0].visible, true)
    eq('one blocker among several is enough to block',
       G.visibility(RX, [behind],
                    [{ minx: 500, maxx: 510, miny: 0, maxy: 60, minz: 500, maxz: 510 },
                     TOWER])[0].visible,
       false)

    var sats = G.constellation(0, 8, 200)
    var sky = G.visibility(RX, sats, [TOWER])
    eq('the report has one entry per satellite', sky.length, sats.length)
    ok('...in the same order, carrying the satellite itself',
       sky.every(function (v, i) { return v.sat === sats[i] }))
    ok('...and a boolean verdict on each',
       sky.every(function (v) { return typeof v.visible === 'boolean' }))
    ok('the tower blocks some but not all of an 8-satellite sky',
       sky.some(function (v) { return v.visible }) &&
       sky.some(function (v) { return !v.visible }))
    eq('an empty sky reports nothing', G.visibility(RX, [], [TOWER]).length, 0)

    var boxed = { minx: -50, maxx: 50, miny: -10, maxy: 60, minz: -50, maxz: 50 }
    eq('a receiver inside a blocker sees nothing at all',
       G.visibility(RX, sats, [boxed]).filter(function (v) { return v.visible }).length, 0)
}

// ------------------------------------------------- the two halves, together
section('gnss + trilateration - the fix the lab draws')
{
    // Exactly the pipeline GpsSensor.qml runs: constellation -> visibility ->
    // pseudoranges -> solve with the clock unknown. Noise-free, so the fix
    // must be exact and the only thing left to vary is geometry.
    var RX = { x: 0, y: 1.6, z: 0 }
    var BIAS = 15
    function fixFrom(blockers, sats) {
        var seen = G.visibility(RX, sats, blockers)
            .filter(function (v) { return v.visible })
            .map(function (v) { return v.sat })
        if (seen.length < 3) return { n: seen.length, sol: null }
        var r = seen.map(function (s) {
            var dx = RX.x - s.x, dy = RX.y - s.y, dz = RX.z - s.z
            return { range: Math.sqrt(dx * dx + dy * dy + dz * dz) + BIAS }
        })
        return { n: seen.length,
                 sol: T.solve(seen, r, { guess: { x: 1, z: 1 }, y: RX.y,
                                         clockUnknown: true, sigmaRange: 2 }) }
    }

    var sats = G.constellation(0, 16, 300)
    var open = fixFrom([], sats)
    eq('open sky: all 16 satellites are visible', open.n, 16)
    ok('...the fix lands on the receiver', errOf(open.sol, { x: 0, z: 0 }) < 1e-6)
    near('...and the clock offset is recovered', open.sol.bias, BIAS, 1e-6)

    // An urban canyon: two long walls leave only a strip of sky. Same
    // satellites, same ranging quality, worse answer - purely from geometry.
    var CANYON = [{ minx: -400, maxx: -40, miny: 0, maxy: 150, minz: -400, maxz: 400 },
                  { minx: 40, maxx: 400, miny: 0, maxy: 150, minz: -400, maxz: 400 }]
    var urban = fixFrom(CANYON, sats)
    ok('the canyon hides most of the sky', urban.n < open.n && urban.n >= 3,
       'saw ' + urban.n)
    ok('...but enough remains for a fix', !!urban.sol)
    ok('...which is still exact, because the ranges are exact',
       errOf(urban.sol, { x: 0, z: 0 }) < 1e-6)
    ok('...while DOP records how much worse the geometry got',
       urban.sol.dop > 4 * open.sol.dop,
       'open ' + open.sol.dop.toFixed(3) + ' vs urban ' + urban.sol.dop.toFixed(3))

    // A slit narrow enough to drop below three satellites: no fix at all,
    // which is the state GpsSensor reports as minSats not met.
    var SLIT = [{ minx: -400, maxx: -6, miny: 0, maxy: 250, minz: -400, maxz: 400 },
                { minx: 6, maxx: 400, miny: 0, maxy: 250, minz: -400, maxz: 400 }]
    var starved = fixFrom(SLIT, sats)
    ok('a slit leaves too few satellites to fix at all',
       starved.n < 3 && starved.sol === null, 'saw ' + starved.n)
}
{
    // The whole pipeline is reproducible from t: two identical runs of the
    // same second must produce byte-identical geometry and the same fix.
    var RX = { x: 2, y: 1.6, z: -3 }
    function run() {
        var sats = G.constellation(12.25, 10, 250)
        var seen = G.visibility(RX, sats, [])
            .filter(function (v) { return v.visible })
            .map(function (v) { return v.sat })
        var r = seen.map(function (s) {
            var dx = RX.x - s.x, dy = RX.y - s.y, dz = RX.z - s.z
            return { range: Math.sqrt(dx * dx + dy * dy + dz * dz) + 4 }
        })
        return T.solve(seen, r, { guess: { x: 0, z: 0 }, y: RX.y,
                                  clockUnknown: true, sigmaRange: 1 })
    }
    eq('the whole pipeline is deterministic in t',
       JSON.stringify(run()), JSON.stringify(run()))
    var s = run()
    near('...and puts the receiver where it is (x)', s.x, RX.x, 1e-6)
    near('...and (z)', s.z, RX.z, 1e-6)
}

process.exit(K.report('sensor kit'))
