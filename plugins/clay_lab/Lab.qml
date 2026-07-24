// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton
import QtQuick

/*!
    \qmltype Lab
    \inqmlmodule Clayground.Lab
    \brief Global registry connecting parameters, probes and the sim clock.

    Every Parameter and Probe registers itself here on creation. UI
    components (ParamPanel, Plot2D) and agents (via eval on the inspector
    protocol) address them by name through this singleton.

    Example usage:
    \qml
    import Clayground.Lab

    // read a parameter value
    property real g: Lab.p("gravity")

    // set one (also the agent-facing entry point)
    Component.onCompleted: Lab.set("gravity", 3.7)
    \endqml

    \sa Parameter, Probe, SimClock
*/
QtObject {
    id: _lab

    /*!
        \qmlproperty var Lab::paramNames
        \readonly
        \brief Names of all registered parameters (registration order).
    */
    property var paramNames: []

    /*!
        \qmlproperty var Lab::probeNames
        \readonly
        \brief Names of all registered probes (registration order).
    */
    property var probeNames: []

    /*!
        \qmlproperty string Lab::scenario
        \brief Name of the currently applied scenario ("" if none).
    */
    property string scenario: ""

    /*!
        \qmlproperty QtObject Lab::clock
        \brief The active SimClock (set automatically by SimClock).
    */
    property QtObject clock: null

    /*!
        \qmlsignal Lab::sampled(real t)
        \brief Emitted after all probes took a sample at sim time t.
    */
    signal sampled(real t)

    property var _params: ({})
    property var _probes: ({})

    function registerParameter(par) {
        if (!par.name) { console.warn("Lab: Parameter without name ignored"); return }
        _params[par.name] = par
        paramNames = Object.keys(_params)
    }

    function unregisterParameter(par) {
        if (_params[par.name] === par) {
            delete _params[par.name]
            paramNames = Object.keys(_params)
        }
    }

    function registerProbe(probe) {
        if (!probe.name) { console.warn("Lab: Probe without name ignored"); return }
        _probes[probe.name] = probe
        probeNames = Object.keys(_probes)
    }

    function unregisterProbe(probe) {
        if (_probes[probe.name] === probe) {
            delete _probes[probe.name]
            probeNames = Object.keys(_probes)
        }
    }

    /*!
        \qmlmethod Parameter Lab::parameter(string name)
        \brief Returns the Parameter with the given name (null if unknown).
    */
    function parameter(name) { return _params[name] ?? null }

    /*!
        \qmlmethod Probe Lab::probe(string name)
        \brief Returns the Probe with the given name (null if unknown).
    */
    function probe(name) { return _probes[name] ?? null }

    /*!
        \qmlmethod real Lab::p(string name)
        \brief Shorthand for the value of the named parameter.
    */
    function p(name) {
        const par = _params[name]
        if (!par) { console.warn("Lab: unknown parameter " + name); return 0 }
        return par.value
    }

    /*!
        \qmlmethod bool Lab::set(string name, real value)
        \brief Sets a parameter value, clamped to its range.
    */
    function set(name, value) {
        const par = _params[name]
        if (!par) { console.warn("Lab: unknown parameter " + name); return false }
        let v = Number(value)
        if (par.to > par.from) v = Math.max(par.from, Math.min(par.to, v))
        par.value = v
        return true
    }

    function takeSamples(t) {
        for (const n of probeNames) _probes[n].sample(t)
        sampled(t)
    }

    /*!
        \qmlmethod void Lab::clearProbes()
        \brief Drops all probe samples (done automatically on SimClock.reset).
    */
    function clearProbes() {
        for (const n of probeNames) _probes[n].clear()
    }

    /*!
        \qmlmethod var Lab::probeSummary()
        \brief Per-probe {first, last, min, max, count} map.
    */
    function probeSummary() {
        const r = {}
        for (const n of probeNames) r[n] = _probes[n].summary()
        return r
    }

    /*!
        \qmlmethod var Lab::labInfo()
        \brief Standard lab state block for the flagInfo()/labInfo() convention.
    */
    function labInfo() {
        const params = {}
        for (const n of paramNames) params[n] = _params[n].value
        return {
            scenario: scenario,
            time: clock ? clock.time : 0,
            seed: clock ? clock.seed : undefined,
            params: params,
            probes: probeSummary()
        }
    }
}
