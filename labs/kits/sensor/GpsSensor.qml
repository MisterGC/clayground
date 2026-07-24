// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// Position fixes at rateHz with Gaussian noise (sigmaM), seeded via the
// SimClock. `available: false` models dropouts (tunnel, jamming).
QtObject {
    id: _gps

    property var clock: null
    property var truePos: null      // () => ({x, y})
    property real sigmaM: 3
    property real rateHz: 1
    property bool available: true

    property var lastFix: null      // {x, y, t}
    property var fixes: []          // recent fixes, newest last
    property int maxFixes: 30
    signal fix(real x, real y, real t)

    property real _due: 0

    function reset() { _due = 0; fixes = []; lastFix = null }

    property Connections _resetConn: Connections {
        target: _gps.clock
        function onWasReset() { _gps.reset() }
    }

    property Connections _tick: Connections {
        target: Lab
        function onSampled(t) {
            if (t < _gps._due - 1.5 / _gps.rateHz) _gps.reset()
            if (t + 1e-9 < _gps._due || !_gps.available || !_gps.truePos || !_gps.clock)
                return
            _gps._due = t + 1 / _gps.rateHz
            const p = _gps.truePos()
            const fx = p.x + _gps.sigmaM * _gps.clock.randomGaussian()
            const fy = p.y + _gps.sigmaM * _gps.clock.randomGaussian()
            _gps.lastFix = {x: fx, y: fy, t: t}
            _gps.fixes = _gps.fixes.concat([_gps.lastFix]).slice(-_gps.maxFixes)
            _gps.fix(fx, fy, t)
        }
    }
}
