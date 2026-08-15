// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import "format.js" as Format

/*!
    \qmltype Probe
    \inqmlmodule Clayground.Lab
    \brief A named observable sampled by the SimClock, auto-registered with Lab.

    Provide \c expr as a function returning a number; the SimClock samples
    all probes on a fixed sim-time grid, which keeps recorded series
    reproducible under seeded, stepped runs.

    Example usage:
    \qml
    import Clayground.Lab

    Probe { name: "kineticEnergy"; unit: "J"; expr: () => world.totalEnergy() }
    \endqml

    \sa Lab, SimClock, Plot2D, DataRecorder
*/
QtObject {
    id: _probe

    /*!
        \qmlproperty string Probe::name
        \brief Unique name used by Lab, Plot2D and DataRecorder.
    */
    property string name: ""

    /*!
        \qmlproperty var Probe::expr
        \brief Function returning the current numeric value.
    */
    property var expr: null

    /*!
        \qmlproperty string Probe::unit
        \brief Display unit, e.g. "J".
    */
    property string unit: ""

    /*!
        \qmlproperty int Probe::capacity
        \brief Maximum retained samples (ring buffer).
    */
    property int capacity: 1200

    /*!
        \qmlproperty real Probe::value
        \readonly
        \brief Most recent sampled value.
    */
    property real value: 0

    /*!
        \qmlproperty var Probe::samples
        \readonly
        \brief Retained samples as [{t, v}, ...].
    */
    property var samples: []

    function sample(t) {
        if (!expr) return
        const v = Number(expr())
        if (!isFinite(v)) return
        value = v
        samples.push({t: t, v: v})
        if (samples.length > capacity) samples.shift()
    }

    /*!
        \qmlmethod void Probe::clear()
        \brief Drops all samples.
    */
    function clear() { samples = []; value = 0 }

    /*!
        \qmlmethod var Probe::summary()
        \brief Returns \c {{first, last, min, max, mean, stddev, count}} over
        the retained samples.

        \c mean and \c stddev come from Welford's online algorithm rather than
        the sum-of-squares shortcut: over the full 1200-sample ring of a
        quantity with a large offset and small noise - a 9.81 baseline
        wobbling by millimetres - the naive form subtracts two nearly equal
        large numbers and can hand back a negative variance. This one cannot.

        \c stddev is the population deviation: a probe's retained series is the
        whole run being described, not a sample drawn from a larger one.
    */
    function summary() {
        const s = samples
        if (s.length === 0) return { count: 0 }
        let mn = s[0].v, mx = s[0].v
        for (const e of s) { if (e.v < mn) mn = e.v; if (e.v > mx) mx = e.v }
        const st = Format.stats(s.map(e => e.v))
        return { first: s[0].v, last: s[s.length - 1].v, min: mn, max: mx,
                 mean: st.mean, stddev: st.stddev, count: s.length }
    }

    Component.onCompleted: Lab.registerProbe(_probe)
    Component.onDestruction: Lab.unregisterProbe(_probe)
}
