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

    /*!
        \qmlproperty bool Lab::headless
        \brief No one is watching: skip audio and character travel.

        Set by \l runFlow() for the length of a headless run and restored
        afterwards; a host may also set it by hand. What honours it is
        deliberately small and listed here rather than guessed at: \l Narrator
        hides, the professor kit's FlowGuide leaves the character where it is,
        and pre-rendered narration is not loaded. Nothing about the SIMULATION
        changes - a flow must traverse the same states headless as it does on
        screen, or running it as a check proves nothing.
    */
    property bool headless: false

    /*!
        \qmlproperty var Lab::flowIds
        \readonly
        \brief Ids of all registered flows (registration order).
    */
    property var flowIds: []

    property var _params: ({})
    property var _probes: ({})
    property var _flows: ({})

    function registerParameter(par) {
        if (!par.name) { console.warn("Lab: Parameter without name ignored"); return }
        _params[par.name] = par
        paramNames = Object.keys(_params)
    }

    function unregisterParameter(par) { unregisterParameterNamed(par.name, par) }

    // Parameter registers as soon as its name arrives, so it also has to be
    // able to withdraw the entry it filed under a PREVIOUS name.
    function unregisterParameterNamed(name, par) {
        if (_params[name] === par) {
            delete _params[name]
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

    function registerFlow(flow) {
        if (!flow.flowId) { console.warn("Lab: Flow without flowId ignored"); return }
        _flows[flow.flowId] = flow
        flowIds = Object.keys(_flows)
    }

    function unregisterFlow(flow) { unregisterFlowNamed(flow.flowId, flow) }

    // Same story as Parameter: a Flow files itself as soon as its id arrives,
    // so it also has to be able to withdraw the entry under a PREVIOUS id.
    function unregisterFlowNamed(id, flow) {
        if (_flows[id] === flow) {
            delete _flows[id]
            flowIds = Object.keys(_flows)
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

    /*!
        \qmlmethod var Lab::runFlow(string flowId, var opts)
        \brief Runs a registered \l Flow to its end with nobody watching.

        The headless half of "every flow is also a test": it starts the flow
        through the lab's own \c startFlow() when the lab has one, forces
        \c {pacing: "auto"}, advances \l clock in fixed 1/60 s steps and
        performs every task itself with \c Flow::solve(). Nothing is waited
        for in wall-clock time, so a whole lesson runs in well under a second.

        Returns what broke rather than throwing:

        \list
        \li \c flowId, \c steps - the id asked for and how many 1/60 s steps it took;
        \li \c unresolvedVerbs - verb names the flow asked the lab for and did
            not get (a missing verb otherwise fails silently);
        \li \c failedTasks - \c {{index, step}} for a task still unsatisfied
            \c opts.solveGrace sim seconds after its own \c solve() ran;
        \li \c failedExpects - \c {{index, step}} (plus \c error when the
            predicate threw) for every \c FlowStep::expect that did not hold,
            asserted the moment the flow leaves the step;
        \li \c finished - the flow reached its end. False means the bound was
            hit;
        \li \c error - the run never started (no such flow, no clock).
        \endlist

        \c opts.maxSteps (default 20000, i.e. ~5.5 sim minutes) bounds the run
        so a \c watch that never comes true is a false \c finished rather than
        a hang. \c opts.solveGrace (default 5 sim seconds) is how long a task
        gets after being solved before it counts as failed.

        \l headless is true for the length of the run and restored afterwards.

        \sa Flow, headless
    */
    function runFlow(flowId, opts) {
        opts = opts ?? ({})
        const maxSteps = opts.maxSteps !== undefined ? opts.maxSteps : 20000
        const grace = Math.max(1, Math.round(
            60 * (opts.solveGrace !== undefined ? opts.solveGrace : 5)))
        const r = { flowId: flowId, steps: 0, unresolvedVerbs: [],
                    failedTasks: [], failedExpects: [], finished: false }

        const f = _flows[flowId]
        if (!f) {
            r.error = "no flow '" + flowId + "'; registered: [" + flowIds.join(", ") + "]"
            return r
        }
        if (!clock) {
            r.error = "no SimClock: a flow is driven in sim time, not in frames"
            return r
        }

        const wasHeadless = headless
        const wasPacing = f.pacing
        headless = true
        f.pacing = "auto"

        // A step's expect is asserted the moment the flow LEAVES the step.
        // Flow.goTo() assigns index BEFORE it runs the next step's demo, so
        // this handler is the last instant at which the lab still holds the
        // state the finished step produced - checking after the loop noticed
        // would assert it against the next step's setup.
        let at = -1
        let asserting = true
        const onIndex = function() {
            if (!asserting) return
            if (at >= 0) _assertExpect(f, at, r)
            at = f.index
        }
        f.indexChanged.connect(onIndex)

        try {
            const root = f.lab
            if (root && typeof root.startFlow === "function") root.startFlow(flowId)
            if (!f.running) f.start()      // no entry point, or it refused
            if (!f.running) {
                r.error = "the flow did not start"
                return r
            }

            let solvedAt = -1
            let solvedStep = 0
            while (f.running && r.steps < maxSteps) {
                const i = f.index
                if (f.waiting) {
                    if (solvedAt !== i) { solvedAt = i; solvedStep = r.steps; f.solve() }
                    else if (r.steps - solvedStep > grace) {
                        // Solved and still not satisfied: report it and walk
                        // on, so one broken task does not eat the whole budget
                        // and hide every step after it.
                        r.failedTasks.push({ index: i, step: _stepKey(f, i) })
                        asserting = false
                        f.next()
                        asserting = true
                        at = f.index
                        continue
                    }
                }
                clock._advance(1 / 60)
                r.steps += 1
            }
            r.finished = !f.running
        } finally {
            asserting = false
            f.indexChanged.disconnect(onIndex)
            if (f.running) f.stop()
            f.pacing = wasPacing
            headless = wasHeadless
            r.unresolvedVerbs = (f.unresolvedVerbs ?? []).slice()
        }
        return r
    }

    function _stepKey(f, i) {
        const s = f.steps[i]
        return s ? s.key : ""
    }

    function _assertExpect(f, i, r) {
        const s = f.steps[i]
        if (!s || !s.expect) return
        let ok = false
        let threw = ""
        try { ok = !!s.expect(f.nameOf) }
        catch (e) { threw = "" + e }
        if (ok) return
        const entry = { index: i, step: s.key }
        if (threw !== "") entry.error = threw
        r.failedExpects.push(entry)
    }

    /*!
        \qmlmethod var Lab::viewState()
        \brief JSON-serializable lab state for the live-loader reload convention.

        Returns \c {{ scenario, time, params }}: the current scenario name (key
        omitted while empty), the sim-clock time and every registered parameter
        value. Sandbox roots merge their own camera/toggle state on top and hand
        the result to the dojo, which re-applies it after the next reload.

        \sa applyViewState
    */
    function viewState() {
        const params = {}
        for (const n of paramNames) params[n] = _params[n].value
        const s = { time: clock ? clock.time : 0, params: params }
        if (scenario !== "") s.scenario = scenario
        return s
    }

    /*!
        \qmlmethod void Lab::applyViewState(var s)
        \brief Restores parameters and, for world-less clocks, re-steps sim time.

        Sets every parameter in \c s.params through the clamped set(), then -
        only when a SimClock exists, is world-less and s.time > 0 -
        deterministically re-steps it to s.time in fixed 1/60 s increments.

        Ordering contract: the Sandbox root MUST apply \c s.scenario BEFORE
        calling this. The scenario apply resets the clock + RNG, so the re-step
        here replays the exact causal chain (takeSamples -> sampled ->
        sensors/filter), restoring bit-identical sim state. World-driven (Box2D)
        clocks cannot be synchronously re-stepped and are left untouched.

        \sa viewState
    */
    function applyViewState(s) {
        if (!s) return
        if (s.params) for (const n in s.params) set(n, s.params[n])
        if (clock && (clock.world === null || clock.world === undefined) && s.time > 0) {
            while (clock.time < s.time - 1e-9) clock._advance(1 / 60)
        }
    }
}
