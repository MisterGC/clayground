// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// Dead reckoning: integrates true motion deltas with a scale bias and a
// seeded heading random walk — smooth but drifting, the classic odometry
// failure mode.
QtObject {
    id: _odo

    property var clock: null
    property var truePos: null       // () => ({x, y})
    property real driftRate: 0.04    // heading random-walk (rad/sqrt(s))
    property real scaleBias: 1.02    // distance over/under-estimation factor

    property real estX: 0
    property real estY: 0

    property var _lastTrue: null
    property real _lastT: -1
    // public: the lidar assumes this heading, so its drift is felt there too
    property real headingErr: 0

    function reset() {
        _lastTrue = null
        _lastT = -1
        headingErr = 0
        if (truePos) { const p = truePos(); estX = p.x; estY = p.y }
    }

    property Connections _resetConn: Connections {
        target: _odo.clock
        function onWasReset() { _odo.reset() }
    }

    property Connections _tick: Connections {
        target: Lab
        function onSampled(t) {
            if (!_odo.truePos || !_odo.clock) return
            if (t < _odo._lastT) _odo.reset()
            const p = _odo.truePos()
            if (_odo._lastTrue === null) {
                _odo.estX = p.x; _odo.estY = p.y
                _odo._lastTrue = p; _odo._lastT = t
                return
            }
            const dt = Math.max(1e-6, t - _odo._lastT)
            _odo.headingErr += _odo.clock.randomGaussian() * _odo.driftRate * Math.sqrt(dt)
            const dx = (p.x - _odo._lastTrue.x) * _odo.scaleBias
            const dy = (p.y - _odo._lastTrue.y) * _odo.scaleBias
            const c = Math.cos(_odo.headingErr), s = Math.sin(_odo.headingErr)
            _odo.estX += dx * c - dy * s
            _odo.estY += dx * s + dy * c
            _odo._lastTrue = p
            _odo._lastT = t
        }
    }
}
