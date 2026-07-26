// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "gnss.js" as Gnss
import "trilateration.js" as Tri

// A receiver, not a noise generator: it sees whichever satellites the world
// leaves in view, measures a pseudorange to each (sigmaM per RANGE, drawn from
// the seeded clock) and solves for position plus its own clock offset. The
// position error is therefore produced - by blockage and by geometry - which is
// why a fix degrades in a street canyon and dies in a tunnel with nobody
// setting a flag.
QtObject {
    id: _gps

    property var clock: null
    property var truePos: null      // () => ({x, y})
    property real sigmaM: 3         // per-range noise, NOT position error
    property real rateHz: 1
    property bool enabled: true     // hard override (receiver off, jamming)

    // what the world offers
    property var satellites: []     // [{id, x, y, z, elevation}], y is up
    property var blockers: []       // [{minx, maxx, miny, maxy, minz, maxz}]
    property real antennaHeight: 0.6
    property int minSats: 3         // 2D + clock (real GPS: 4, it also solves z)

    // what the receiver reports
    property var lastFix: null      // {x, y, t}
    property var fixes: []          // recent fixes, newest last
    property int maxFixes: 30
    property var sky: []            // [{sat, visible}] - what it can see
    property int visibleCount: 0
    property real hdop: 0           // geometry, as a number
    property real posSigma: 0       // sigmaM * hdop: what this fix is worth
    readonly property bool available: enabled && visibleCount >= minSats
    signal fix(real x, real y, real t)

    // 1 -> 0 after every fix: the visuals use it to show the solve landing
    property real fixPulse: 0
    property PropertyAnimation _pulseAnim: PropertyAnimation {
        target: _gps; property: "fixPulse"; from: 1; to: 0; duration: 420
    }

    property real _due: 0
    property var _guess: ({ x: 0, z: 0, bias: 0 })
    property real _clockBias: 12.0  // the receiver's own offset, solved for

    function reset() {
        _due = 0; fixes = []; lastFix = null
        _guess = ({ x: 0, z: 0, bias: 0 })
        sky = []; visibleCount = 0; hdop = 0; posSigma = 0
    }

    property Connections _resetConn: Connections {
        target: _gps.clock
        function onWasReset() { _gps.reset() }
    }

    property Connections _tick: Connections {
        target: Lab
        function onSampled(t) {
            if (!_gps.truePos || !_gps.clock) return
            if (t < _gps._due - 1.5 / _gps.rateHz) _gps.reset()

            // The sky is re-evaluated every tick, not only on a fix, so the
            // signal lines and the "how many can I see" readout stay live.
            const p = _gps.truePos()
            const rx = { x: p.x, y: _gps.antennaHeight, z: p.y }
            const seen = Gnss.visibility(rx, _gps.satellites, _gps.blockers)
            _gps.sky = seen
            const vis = seen.filter(s => s.visible).map(s => s.sat)
            _gps.visibleCount = vis.length

            if (t + 1e-9 < _gps._due || !_gps.enabled) return
            _gps._due = t + 1 / _gps.rateHz
            if (vis.length < _gps.minSats) { _gps.hdop = 0; _gps.posSigma = 0; return }

            // pseudorange = true range + the receiver's clock offset + noise
            const ranges = vis.map(s => {
                const dx = rx.x - s.x, dy = rx.y - s.y, dz = rx.z - s.z
                return Math.sqrt(dx * dx + dy * dy + dz * dz)
                       + _gps._clockBias + _gps.sigmaM * _gps.clock.randomGaussian()
            })
            const sol = Tri.solve(vis, ranges.map(r => ({ range: r })), {
                guess: _gps._guess, y: _gps.antennaHeight, clockUnknown: true,
                sigmaRange: _gps.sigmaM })
            if (!sol) return

            _gps._guess = { x: sol.x, z: sol.z, bias: sol.bias }
            _gps.hdop = sol.dop
            _gps.posSigma = sol.sigma
            _gps.lastFix = { x: sol.x, y: sol.z, t: t }
            _gps.fixes = _gps.fixes.concat([_gps.lastFix]).slice(-_gps.maxFixes)
            _gps._pulseAnim.restart()
            _gps.fix(sol.x, sol.z, t)
        }
    }
}
