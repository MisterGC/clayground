// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// Landmark-based lidar odometry, simplified: when known landmarks are in
// range, scan matching yields a position fix with small noise (sigmaM).
// No landmarks in range -> no fix. `hits` carries the matched landmarks
// for beam visualization.
QtObject {
    id: _lidar

    property var clock: null
    property var truePos: null       // () => ({x, y})
    property var landmarks: []       // [{x, y}]
    property real range: 22
    property real sigmaM: 0.5
    property real rateHz: 10
    property bool enabled: true

    property var lastFix: null       // {x, y, t}
    property var hits: []            // landmarks used by the last scan
    signal fix(real x, real y, real t)

    property real _due: 0

    function reset() { _due = 0; lastFix = null; hits = [] }

    property Connections _resetConn: Connections {
        target: _lidar.clock
        function onWasReset() { _lidar.reset() }
    }

    property Connections _tick: Connections {
        target: Lab
        function onSampled(t) {
            if (t < _lidar._due - 1.5 / _lidar.rateHz) _lidar.reset()
            if (t + 1e-9 < _lidar._due || !_lidar.enabled || !_lidar.truePos || !_lidar.clock)
                return
            _lidar._due = t + 1 / _lidar.rateHz
            const p = _lidar.truePos()
            const inRange = []
            for (const lm of _lidar.landmarks) {
                const dx = lm.x - p.x, dy = lm.y - p.y
                if (dx * dx + dy * dy <= _lidar.range * _lidar.range) inRange.push(lm)
            }
            if (inRange.length === 0) { _lidar.hits = []; return }
            const fx = p.x + _lidar.sigmaM * _lidar.clock.randomGaussian()
            const fy = p.y + _lidar.sigmaM * _lidar.clock.randomGaussian()
            _lidar.hits = inRange
            _lidar.lastFix = {x: fx, y: fy, t: t}
            _lidar.fix(fx, fy, t)
        }
    }
}
