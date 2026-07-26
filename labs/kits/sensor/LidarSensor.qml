// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "trilateration.js" as Tri
import "gnss.js" as Gnss

// Landmark localisation against a KNOWN MAP. A lidar on its own only measures
// where things are relative to the car; it becomes a position sensor when the
// map says which surveyed object each detection is. So this sensor takes the
// map (`landmarks`), sees whichever entries are in range AND unoccluded,
// measures range plus bearing to each, and solves for the car's position.
//
// Position AND heading come out of the solve: with range plus bearing to two
// identified landmarks there are four constraints for three unknowns, so the
// sensor never has to borrow an orientation it cannot check.
//
// Simplifications, deliberately: perfect data association (a real stack can
// mis-associate, which produces gross errors rather than noise) and landmarks
// are points rather than façades (this is landmark localisation, not scan
// matching against surfaces).
QtObject {
    id: _lidar

    property var clock: null
    property var truePos: null        // () => ({x, y})
    property real trueHeading: 0      // world heading of the car, radians
    property real assumedHeadingError: 0   // what the odometry believes, minus truth

    property var landmarks: []        // THE MAP: [{x, y}] surveyed positions
    property var blockers: []         // [{minx,maxx,miny,maxy,minz,maxz}], map order
    property real range: 22
    property real sigmaM: 0.5         // per-range noise
    property real bearingSigma: 0.02  // per-bearing noise, radians (~1.1 deg)
    /*! Estimate heading along with position (the honest default). With false,
        the assumed heading is taken as truth - which is how a real stack
        acquires a silent bias it does not report. */
    property bool solveHeading: true
    property real rateHz: 10
    property real sensorHeight: 0.6
    property int minLandmarks: 2
    property bool enabled: true

    property var lastFix: null        // {x, y, t}
    property var hits: []             // landmarks that produced the fix
    // The raw sensor output, in the sensor's OWN frame: what a lidar actually
    // delivers is relative geometry. `range`/`bearing` are the noisy
    // measurements, `x`/`y` the map entry each one was associated with - the
    // pairing is what makes an absolute position possible at all.
    property var detections: []       // [{range, bearing, x, y}]
    property var hidden: []           // map entries in range but occluded
    property int usedCount: 0
    property real headingFix: 0       // the heading the solve settled on
    property real dop: 0              // geometry alone
    property real posSigma: 0         // what the fix is worth, in metres
    readonly property bool available: enabled && usedCount >= minLandmarks
    signal fix(real x, real y, real t)

    property real _due: 0
    property var _guess: null

    function reset() {
        _due = 0; lastFix = null; hits = []; detections = []; hidden = []
        usedCount = 0; headingFix = 0; dop = 0; posSigma = 0; _guess = null
    }

    property Connections _resetConn: Connections {
        target: _lidar.clock
        function onWasReset() { _lidar.reset() }
    }

    // --- the raw scan ----------------------------------------------------
    // A silhouette of whatever surface is nearest along each ray - the point
    // cloud a spinning lidar produces. Deliberately separate from the fix: this
    // is relative geometry ONLY, it says nothing about where the car is. The
    // monitor draws it from here rather than re-simulating it, so the panel and
    // the sensor always agree about what the world contains.
    //
    // Ranges get hash-based jitter, not RNG-stream jitter, so drawing the scan
    // can never disturb the lab's determinism contract.
    function scan(count) {
        const out = []
        if (!truePos || !enabled) return out
        const p = truePos()
        const idx = clock ? Math.floor(clock.time * rateHz) : 0
        for (let i = 0; i < count; ++i) {
            const bearing = i / count * 2 * Math.PI
            const world = trueHeading + bearing
            const d = _rayCast(p.x, p.y, Math.sin(world), Math.cos(world))
            if (d < 0 || d > range) continue
            const h = Math.sin(i * 127.1 + idx * 311.7) * 43758.5453
            out.push({ bearing: bearing,
                       range: d + (h - Math.floor(h) - 0.5) * 2 * sigmaM })
        }
        return out
    }

    // nearest blocker along a horizontal ray at sensor height, -1 for a miss
    function _rayCast(ox, oz, dx, dz) {
        let best = -1
        for (let b = 0; b < blockers.length; ++b) {
            const box = blockers[b]
            if (sensorHeight < box.miny || sensorHeight > box.maxy) continue
            let tmin = -Infinity, tmax = Infinity
            const axes = [[ox, dx, box.minx, box.maxx], [oz, dz, box.minz, box.maxz]]
            let miss = false
            for (let a = 0; a < 2 && !miss; ++a) {
                const o = axes[a][0], d = axes[a][1], lo = axes[a][2], hi = axes[a][3]
                if (Math.abs(d) < 1e-9) {
                    if (o < lo || o > hi) miss = true
                } else {
                    let t1 = (lo - o) / d, t2 = (hi - o) / d
                    if (t1 > t2) { const s = t1; t1 = t2; t2 = s }
                    tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2)
                    if (tmin > tmax) miss = true
                }
            }
            if (miss || tmax < Math.max(tmin, 0)) continue
            const t = tmin > 0 ? tmin : -1
            if (t > 0 && (best < 0 || t < best)) best = t
        }
        return best
    }

    // in range, and actually observable: a landmark hidden behind another
    // building is not a measurement, however close it is
    function _observable(rx, lm, index) {
        const dx = lm.x - rx.x, dz = lm.y - rx.z
        if (dx * dx + dz * dz > _lidar.range * _lidar.range) return false
        const to = { x: lm.x, y: _lidar.sensorHeight, z: lm.y }
        for (let b = 0; b < _lidar.blockers.length; ++b) {
            if (b === index) continue          // a landmark cannot occlude itself
            if (Gnss.segmentHitsBox(rx, to, _lidar.blockers[b])) return false
        }
        return true
    }

    property Connections _tick: Connections {
        target: Lab
        function onSampled(t) {
            if (!_lidar.truePos || !_lidar.clock) return
            if (t < _lidar._due - 1.5 / _lidar.rateHz) _lidar.reset()
            if (t + 1e-9 < _lidar._due || !_lidar.enabled) return
            _lidar._due = t + 1 / _lidar.rateHz

            const p = _lidar.truePos()
            const rx = { x: p.x, y: _lidar.sensorHeight, z: p.y }
            // sort the map into what can be measured and what cannot: in range
            // but behind something is a map entry the car may NOT use
            const seen = [], blocked = []
            for (let i = 0; i < _lidar.landmarks.length; ++i) {
                const lm = _lidar.landmarks[i]
                const dx = lm.x - rx.x, dz = lm.y - rx.z
                if (dx * dx + dz * dz > _lidar.range * _lidar.range) continue
                if (_lidar._observable(rx, lm, i)) seen.push(lm)
                else blocked.push(lm)
            }
            _lidar.hits = seen
            _lidar.hidden = blocked
            _lidar.usedCount = seen.length
            if (seen.length < _lidar.minLandmarks) {
                _lidar.detections = []
                _lidar.dop = 0; _lidar.posSigma = 0
                return
            }

            // measure: range and bearing to each identified landmark
            const anchors = seen.map(l => ({ x: l.x, y: _lidar.sensorHeight, z: l.y }))
            const heading = _lidar.trueHeading + _lidar.assumedHeadingError
            const meas = anchors.map(a => {
                const dx = a.x - rx.x, dz = a.z - rx.z
                return {
                    range: Math.sqrt(dx * dx + dz * dz)
                           + _lidar.sigmaM * _lidar.clock.randomGaussian(),
                    bearing: Math.atan2(dx, dz) - _lidar.trueHeading
                             + _lidar.bearingSigma * _lidar.clock.randomGaussian()
                }
            })
            // the raw output, published for anyone drawing the sensor: the
            // measurement paired with the map entry it was associated with
            _lidar.detections = meas.map((m, i) => ({
                range: m.range, bearing: m.bearing, x: seen[i].x, y: seen[i].y }))
            // Heading is an UNKNOWN, not an input: the odometry only supplies a
            // starting guess. Trusting a drifting heading instead of solving it
            // biases the fix by about range * headingError while the covariance
            // reports business as usual - measured at 4.6 m of error behind a
            // sigma of 0.32 m. `solveHeading: false` reproduces that on purpose.
            const sol = Tri.solve(anchors, meas, {
                guess: _lidar._guess ? _lidar._guess : { x: rx.x, z: rx.z },
                y: _lidar.sensorHeight, heading: heading,
                headingUnknown: _lidar.solveHeading,
                sigmaRange: _lidar.sigmaM, sigmaBearing: _lidar.bearingSigma })
            if (!sol) { _lidar.dop = 0; _lidar.posSigma = 0; return }

            _lidar.headingFix = sol.heading
            _lidar._guess = { x: sol.x, z: sol.z }
            _lidar.dop = sol.dop
            _lidar.posSigma = sol.sigma
            _lidar.lastFix = { x: sol.x, y: sol.z, t: t }
            _lidar.fix(sol.x, sol.z, t)
        }
    }
}
