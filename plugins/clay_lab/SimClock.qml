// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Common

/*!
    \qmltype SimClock
    \inqmlmodule Clayground.Lab
    \brief Seeded simulation clock driving deterministic probe sampling.

    The heart of the determinism contract: all lab randomness must come
    from this clock's seeded generator, and probes are sampled on a fixed
    sim-time grid. With a \c world assigned, sim time advances with the
    physics steps (exact under the inspector's time/step action);
    without one, a frame ticker advances it, honoring Clayground.paused
    and Clayground.timeScale.

    Example usage:
    \qml
    import Clayground.Lab

    SimClock { id: clock; seed: 42; world: theWorld }
    \endqml

    \sa Lab, Probe
*/
QtObject {
    id: _clock

    /*!
        \qmlproperty int SimClock::seed
        \brief Seed for the deterministic random generator; changing it resets the clock.
    */
    property int seed: 42

    /*!
        \qmlproperty real SimClock::time
        \readonly
        \brief Simulated seconds since the last reset.
    */
    property real time: 0

    /*!
        \qmlproperty real SimClock::sampleInterval
        \brief Sim-time seconds between probe samples.
    */
    property real sampleInterval: 0.1

    /*!
        \qmlproperty var SimClock::world
        \brief Optional ClayWorld2d; when set, time advances with physics steps.
    */
    property var world: null

    /*!
        \qmlproperty real SimClock::timeScale
        \brief Slow-motion/fast-forward factor for live (frame-driven) mode.

        Composes with Clayground.timeScale; ignored while stepping, which
        always advances fixed frames for reproducibility.
    */
    property real timeScale: 1

    /*!
        \qmlsignal SimClock::wasReset()
        \brief Emitted after a reset; sensors/estimators snap their state here.
    */
    signal wasReset()

    property double _rngState: 0
    property real _nextSample: 0

    /*!
        \qmlmethod void SimClock::reset()
        \brief Resets time, random state and all probe samples.
    */
    function reset() {
        _rngState = (seed >>> 0)
        time = 0
        _nextSample = 0
        Lab.clearProbes()
        wasReset()
    }

    /*!
        \qmlmethod real SimClock::random()
        \brief Deterministic uniform random number in [0, 1) (mulberry32).
    */
    function random() {
        _rngState = (_rngState + 0x6D2B79F5) | 0
        let t = _rngState
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }

    /*!
        \qmlmethod real SimClock::randomRange(real from, real to)
        \brief Deterministic uniform random number in [from, to).
    */
    function randomRange(from, to) { return from + (to - from) * random() }

    /*!
        \qmlmethod real SimClock::randomGaussian()
        \brief Deterministic standard-normal random number (Box-Muller).
    */
    function randomGaussian() {
        return Math.sqrt(-2 * Math.log(1 - random())) * Math.cos(2 * Math.PI * random())
    }

    function _advance(dt) {
        time += dt
        while (time + 1e-9 >= _nextSample) {
            Lab.takeSamples(_nextSample)
            _nextSample += sampleInterval
        }
    }

    onSeedChanged: reset()
    Component.onCompleted: { Lab.clock = _clock; reset() }

    property Connections _stepConn: Connections {
        target: _clock.world ? _clock.world.physics : null
        ignoreUnknownSignals: true
        function onStepped() { _clock._advance(_clock.world.physics.timeStep) }
    }

    property FrameAnimation _frameTicker: FrameAnimation {
        running: !_clock.world && !Clayground.paused
        onTriggered: _clock._advance(frameTime * Clayground.timeScale * _clock.timeScale)
    }

    // World-less labs act as their own "world-like component": consume the
    // inspector's step request so time-driven sims stay step-exact.
    property Connections _stepRequest: Connections {
        target: !_clock.world ? Clayground : null
        function onPhysicsStep(frames) {
            // one fixed step at a time so bindings and samples see every
            // intermediate sim state (mirrors the Box2D stepping loop)
            for (let i = 0; i < frames; ++i) _clock._advance(1 / 60.0)
            Clayground.ackStep(frames)
        }
    }
}
