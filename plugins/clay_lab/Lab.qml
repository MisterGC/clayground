// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton
import QtQuick
import Clayground.Text
import "record.js" as Record

/*!
    \qmltype Lab
    \inqmlmodule Clayground.Lab
    \ingroup lab-kernel
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
        \qmlproperty var Lab::host
        \brief The sandbox root: what supplies \c scenarios() and \c applyScenario().

        Set by \l LabKeys from its \c lab, which every lab has, and cleared
        when that LabKeys goes; a host without one sets it by hand. \l run()
        applies a scenario through it, because a lab's own \c applyScenario()
        does more than its ScenarioSet - street-network-101's frames the plan
        and resets the clock after the script.
    */
    property var host: null

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

    /*!
        \qmlproperty var Lab::modelStateNames
        \readonly
        \brief Names of all registered \l ModelState hooks (registration order).

        Empty means the lab's model offers no state: \l snapshot() says so,
        and a reload replays the run instead.
    */
    property var modelStateNames: []

    /*!
        \qmlsignal Lab::restored()
        \brief Emitted after \l restore() put a snapshot back.

        Sim time and the probe samples jumped without a single sample being
        taken, so whatever redraws on \l sampled redraws on this too.
    */
    signal restored()

    property var _params: ({})
    property var _probes: ({})
    property var _flows: ({})
    property var _models: ({})
    property var _recorders: []
    // Parameter values when the clock was last reset, and every change since
    // as [simTime, name, value] - what a replay needs to apply each change at
    // the time it was made instead of all of them at the start.
    property var _paramStart: ({})
    property var _paramLog: []
    property TextWriter _writer: TextWriter {}
    property TextReader _reader: TextReader {}

    readonly property string _snapshotFormat: "clay-lab-snapshot/1"

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

    function registerModelState(m) {
        if (!m.name) { console.warn("Lab: ModelState without name ignored"); return }
        if (_models[m.name] && _models[m.name] !== m)
            console.warn("Lab: a second ModelState named " + m.name
                         + " replaces the first - a snapshot holds one state per name")
        _models[m.name] = m
        modelStateNames = Object.keys(_models)
    }

    function unregisterModelState(m) {
        if (_models[m.name] === m) {
            delete _models[m.name]
            modelStateNames = Object.keys(_models)
        }
    }

    function registerRecorder(r) {
        if (_recorders.indexOf(r) === -1) _recorders.push(r)
    }

    function unregisterRecorder(r) {
        const i = _recorders.indexOf(r)
        if (i !== -1) _recorders.splice(i, 1)
    }

    // SimClock.reset() calls this: the run the log describes starts here.
    function _clockReset() {
        const start = {}
        for (const n of paramNames) start[n] = _params[n].value
        _paramStart = start
        _paramLog = []
    }

    // Parameter.onValueChanged calls this. Changes at one sim time collapse
    // into the last of them: a slider dragged while the clock stands still
    // is one change, not a hundred.
    function _paramChanged(par) {
        if (_params[par.name] !== par) return
        const t = clock ? clock.time : 0
        const last = _paramLog.length ? _paramLog[_paramLog.length - 1] : null
        if (last && last[0] === t && last[1] === par.name) last[2] = par.value
        else _paramLog.push([t, par.name, par.value])
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
        \brief Sets a parameter value; refuses one outside its range.

        Returns false and logs a warning naming the range when \a value is
        not a number or lies outside \c{[from, to]} of a parameter that has a
        range (\c{to > from}); the value is left as it was. It used to clamp
        without a word, so an experiment asked for a GPS noise of 12 on a 0.5
        to 10 slider ran at 10 and its record said nothing about it.
    */
    function set(name, value) {
        const par = _params[name]
        if (!par) { console.warn("Lab: unknown parameter " + name); return false }
        const v = Number(value)
        if (isNaN(v)) {
            console.warn("Lab: parameter " + name + " is not set to " + value
                         + " - not a number")
            return false
        }
        if (par.to > par.from && (v < par.from || v > par.to)) {
            console.warn("Lab: parameter " + name + " is not set to " + v
                         + " - outside its range " + par.from + " to " + par.to)
            return false
        }
        par._keepDefault()
        par.value = v
        return true
    }

    /*!
        \qmlmethod void Lab::resetParameters()
        \brief Puts every registered parameter back to its \c defaultValue.

        Touches parameters only: the clock, the probes and the scenario stay
        as they are. Applying a scenario resets the clock; this is the other
        half of a clean start without a reload.

        \sa Parameter::reset
    */
    function resetParameters() {
        for (const n of paramNames) _params[n].reset()
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
        \qmlmethod var Lab::schema()
        \brief What this lab can be asked: its parameters, probes, scenarios and flows.

        Returns \c {{params, probes, scenarios, flows, modelStates, clock}}:

        \list
        \li \c params - one \c {{name, value, defaultValue, from, to, stepSize,
            unit, description}} per parameter, in registration order. \c from
            and \c to are the range \l set() and \l run() hold a value to;
        \li \c probes - one \c {{name, unit}} per probe;
        \li \c scenarios - the names \l host's \c scenarios() returns (empty
            without a host);
        \li \c flows - the registered \l Flow ids;
        \li \c modelStates - the registered \l ModelState names; empty when
            the model offers no state and \l snapshot() cannot be taken;
        \li \c clock - \c {{seed, sampleInterval, fixedStep}} of \l clock, or
            null without one.
        \endlist

        \c description is the text the lab declared, in whatever language it
        declared it in; \l labInfo() stays ids and values only.

        \sa run, labInfo
    */
    function schema() {
        const params = []
        for (const n of paramNames) {
            const p = _params[n]
            p._keepDefault()
            params.push({ name: n, value: p.value, defaultValue: p.defaultValue,
                          from: p.from, to: p.to, stepSize: p.stepSize,
                          unit: p.unit, description: p.description })
        }
        const probes = []
        for (const n of probeNames) probes.push({ name: n, unit: _probes[n].unit })
        const sc = host && typeof host.scenarios === "function" ? host.scenarios() : []
        return {
            params: params,
            probes: probes,
            scenarios: sc ? Array.from(sc) : [],
            flows: flowIds.slice(),
            modelStates: modelStateNames.slice(),
            clock: clock ? { seed: clock.seed, sampleInterval: clock.sampleInterval,
                             fixedStep: clock.fixedStep } : null
        }
    }

    /*!
        \qmlmethod var Lab::run(var opts)
        \brief Runs one experiment in fixed steps and returns its probes' summaries.

        The one-off form of a \c lab-sweep study: one call instead of a
        manifest. \a opts:

        \list
        \li \c scenario - applied through \l host's \c applyScenario().
            Omitted, the current \l scenario is applied again, so a run never
            starts from what the previous one left behind;
        \li \c seed - the clock's seed (default: the seed it has);
        \li \c params - \c {{name: value}}. Every parameter is put back to
            its \c defaultValue (\l resetParameters()) before the scenario,
            so one the run does not name starts where a fresh load has it;
        \li \c warmupSteps - steps advanced before recording starts (default 0);
        \li \c steps - steps recorded (default 600);
        \li \c stepHz - steps per sim second (default 60);
        \li \c probes - the probe names to report (default: all);
        \li \c series - true to add each probe's samples.
        \endlist

        The order is the one \c tools/lab-sweep/lab_sweep.py documents: seed,
        scenario, parameters, clock reset, warm-up, record. Parameters are set
        before the reset so that whatever the lab rebuilds on \c wasReset is
        built with them.

        Returns \c {{scenario, seed, warmupSteps, steps, stepSize,
        sampleInterval, duration, params, probes}}: \c params is every
        parameter's value as run, \c probes maps a name to \c {{unit, count,
        first, last, min, max, mean, stddev}} over the RECORDED samples only -
        not the warm-up - computed the way a run record computes them, so a
        mean here is the mean a \c .labrec of the same run holds. The
        summaries are the run's own: a probe keeps its last 1200 samples and
        a longer run is still summarized in full. With \c series, \c series
        maps a name to \c {[[t, v], ...]}, every sample of the run.

        Nothing is run when something in \a opts is wrong - an unknown
        parameter or probe, a value \l set() refuses, a scenario the host
        does not have: the result is then \c {{error}}.

        \sa schema, runFlow
    */
    function run(opts) {
        opts = opts ?? ({})
        if (!clock) return { error: "no SimClock: a run is stepped in sim time" }
        if (clock.world && clock.world.physics)
            return { error: "the clock is driven by a physics world, which "
                            + "cannot be stepped from here" }

        const hz = opts.stepHz !== undefined ? Number(opts.stepHz) : 60
        const warm = opts.warmupSteps !== undefined ? Number(opts.warmupSteps) : 0
        const steps = opts.steps !== undefined ? Number(opts.steps) : 600
        if (!(hz > 0)) return { error: "stepHz must be above 0, not " + opts.stepHz }
        for (const [k, v] of [["warmupSteps", warm], ["steps", steps]])
            if (!(v >= 0) || Math.floor(v) !== v)
                return { error: k + " must be a whole number of steps, not " + v }

        const given = opts.params ?? ({})
        for (const n in given) {
            const p = _params[n]
            if (!p) return { error: "no parameter '" + n + "'; registered: ["
                                    + paramNames.join(", ") + "]" }
            const v = Number(given[n])
            if (isNaN(v) || (p.to > p.from && (v < p.from || v > p.to)))
                return { error: "parameter " + n + " cannot be " + given[n]
                                + " - its range is " + p.from + " to " + p.to }
        }
        const names = opts.probes ? Array.from(opts.probes) : probeNames.slice()
        for (const n of names)
            if (!_probes[n]) return { error: "no probe '" + n + "'; registered: ["
                                             + probeNames.join(", ") + "]" }

        const sc = opts.scenario !== undefined ? String(opts.scenario) : scenario
        if (sc !== "") {
            if (!host || typeof host.applyScenario !== "function")
                return { error: "no host with applyScenario() to apply scenario '"
                                + sc + "' - set Lab.host" }
            const known = typeof host.scenarios === "function"
                ? Array.from(host.scenarios() ?? []) : null
            if (known && known.indexOf(sc) === -1)
                return { error: "no scenario '" + sc + "'; the lab has: ["
                                + known.join(", ") + "]" }
        }

        // seed -> scenario -> parameters -> reset -> warm-up -> record. The
        // defaults go back BEFORE the scenario: a scenario may set parameters
        // of its own, and a fresh load applies it over the defaults too.
        if (opts.seed !== undefined) clock.seed = Number(opts.seed)
        resetParameters()
        if (sc !== "") host.applyScenario(sc)
        for (const n in given) set(n, given[n])
        clock.reset()

        const dt = 1 / hz
        for (let i = 0; i < warm; ++i) clock._advance(dt)

        const accs = names.map(() => Record.accInit())
        const series = opts.series ? names.map(() => []) : null
        // A probe keeps only finite samples, so "did it sample at this tick?"
        // is "is its newest sample this tick?" - the rule DataRecorder uses,
        // which is what makes these summaries the record's.
        const onSampled = function(t) {
            for (let c = 0; c < names.length; ++c) {
                const s = _probes[names[c]].samples
                if (s.length === 0 || s[s.length - 1].t !== t) continue
                const v = s[s.length - 1].v
                Record.accAdd(accs[c], v)
                if (series) series[c].push([t, v])
            }
        }
        let duration = clock.time
        sampled.connect(onSampled)
        try {
            for (let i = 0; i < steps; ++i) clock._advance(dt)
        } finally {
            sampled.disconnect(onSampled)
        }
        duration = clock.time - duration

        const params = {}
        for (const n of paramNames) params[n] = _params[n].value
        const r = {
            scenario: scenario, seed: clock.seed,
            warmupSteps: warm, steps: steps, stepSize: dt,
            sampleInterval: clock.sampleInterval, duration: duration,
            params: params, probes: {}
        }
        for (let c = 0; c < names.length; ++c) {
            const s = Record.accSummary(accs[c])
            s.unit = _probes[names[c]].unit
            r.probes[names[c]] = s
        }
        if (series) {
            r.series = {}
            for (let c = 0; c < names.length; ++c) r.series[names[c]] = series[c]
        }
        return r
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
            asserted the moment the flow leaves the step. An expect that names
            what it looks at through its second argument, \c saw(label,
            value), adds \c saw: \c {{label: value}} - the values it saw;
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

    // A value as JSON carries it: a number that is not finite, or something
    // JSON has no form for, comes back as its String() rather than null.
    function _plain(v) {
        if (v === null || v === undefined) return v === null ? null : "undefined"
        if (typeof v === "number") return isFinite(v) ? v : String(v)
        if (typeof v === "boolean" || typeof v === "string") return v
        if (Array.isArray(v)) return v.map(_plain)
        if (typeof v === "object") {
            const o = {}
            for (const k in v) if (typeof v[k] !== "function") o[k] = _plain(v[k])
            return o
        }
        return String(v)
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
        // What the expect looked at, as it says through saw(label, value):
        // "expect failed" alone sends the reader to rerun the lesson by hand
        // to find out whether a current was off by a hair or by an order.
        const seen = {}
        let named = false
        const saw = function(label, value) {
            seen[String(label)] = value
            named = true
            return value
        }
        try { ok = !!s.expect(f.nameOf, saw) }
        catch (e) { threw = "" + e }
        if (ok) return
        const entry = { index: i, step: s.key }
        if (threw !== "") entry.error = threw
        if (named) entry.saw = _plain(seen)
        r.failedExpects.push(entry)
    }

    // --- snapshots ---------------------------------------------------------

    /*!
        \qmlmethod var Lab::snapshot()
        \brief The state of the running lab as plain data, for \l restore().

        Everything a run needs to go on from here exactly as it would have
        without being interrupted:

        \list
        \li \c clock - the seed and the clock's five values: \c time,
            \c random (the generator's state), \c nextSample, \c stepRemainder
            (the part of a fixed step still to come) and \c lastStepTime;
        \li \c scenario and \c params - every registered parameter's value;
        \li \c paramLog - the parameter values at the clock's last reset and
            every change since, with the sim time it was made at;
        \li \c probes - each probe's retained samples and last value;
        \li \c model - what every registered \l ModelState saves, by name;
        \li \c recorders - for each \l DataRecorder in registration order,
            the run it is recording (null when it is not), so a record
            finished after a restore holds the whole run.
        \endlist

        Non-finite numbers are written as \c {{"$num": "NaN"}} and the like,
        so the result goes through JSON unchanged: \l writeSnapshot() and
        \l readSnapshot() take it to a file and back.

        What it does not hold: how the frame ticker is paced (\c timeScale,
        \c Clayground.paused, a resting clock), the camera and what the
        sandbox shows - that is \c viewState()'s - and a recorder writing
        CSV, whose rows are on disk already (listed in \c notes).

        Returns \c {{error}} instead when there is nothing it could restore
        faithfully: no clock, a clock driven by a physics world, or a model
        that offers no state - a lab that registers no ModelState.

        \sa restore, ModelState, writeSnapshot
    */
    function snapshot() {
        if (!clock) return { error: "no SimClock: a snapshot is taken in sim time" }
        if (clock.world && clock.world.physics)
            return { error: "the clock is driven by a physics world, whose "
                            + "bodies a snapshot cannot hold" }
        if (modelStateNames.length === 0)
            return { error: "this lab's model offers no state: it registers no "
                            + "ModelState, so a snapshot could not hold what its "
                            + "model has built up. A reload replays its run instead." }
        const notes = []
        const model = {}
        for (const n of modelStateNames) model[n] = _pack(_models[n]._save())
        const probes = {}
        for (const n of probeNames) {
            const pr = _probes[n]
            const ts = [], vs = []
            for (const e of pr.samples) { ts.push(e.t); vs.push(e.v) }
            probes[n] = { value: _pack(pr.value), t: ts, v: vs }
        }
        const recorders = []
        for (const r of _recorders) {
            if (r.recording && r._csv) {
                notes.push("a DataRecorder writing CSV to " + r.destination
                           + " is not carried: its rows are on disk already")
                recorders.push(null)
            } else recorders.push(r.recording ? r._snapshot() : null)
        }
        const params = {}
        for (const n of paramNames) params[n] = _pack(_params[n].value)
        const snap = {
            format: _snapshotFormat,
            scenario: scenario,
            clock: { seed: clock.seed, time: clock.time, random: clock._rngState,
                     nextSample: clock._nextSample, stepRemainder: clock._stepAccum,
                     lastStepTime: clock._lastStepTime },
            params: params,
            paramLog: { start: _pack(_paramStart), changes: _pack(_paramLog) },
            probes: probes,
            model: model,
            recorders: recorders
        }
        if (notes.length) snap.notes = notes
        return snap
    }

    /*!
        \qmlmethod var Lab::restore(var snap)
        \brief Puts a \l snapshot() back; the run goes on as if never left.

        \a snap is what \l snapshot() or \l readSnapshot() returned, or the
        path of a file \l writeSnapshot() wrote. Order: the seed (changing it
        resets the clock), the scenario name, the parameters, each
        \l ModelState's state, the clock's values, the probe samples, the
        recorders and the parameter log. \l restored is emitted last.

        Nothing is changed when the snapshot cannot be restored into this lab
        - not a snapshot, no clock, or model state that does not match: the
        snapshot must hold a state for exactly the ModelState names the lab
        registers, because restoring half a model is a run nobody made. The
        result is then \c {{error}}.

        Otherwise it is \c {{restored: true, time, scenario}}, plus \c notes
        for what did not match and was let go: a parameter or probe the
        snapshot has and the lab does not (ignored), a probe the lab has and
        the snapshot does not (left empty), a recorder recording now that the
        snapshot had not (started again from here).

        \sa snapshot, readSnapshot
    */
    function restore(snap) {
        if (typeof snap === "string") snap = readSnapshot(snap)
        if (!snap || typeof snap !== "object") return { error: "not a snapshot: " + snap }
        if (snap.error) return { error: "no snapshot to restore: " + snap.error }
        if (snap.format !== _snapshotFormat)
            return { error: "not a snapshot of format " + _snapshotFormat
                            + ": format is " + snap.format }
        if (!clock) return { error: "no SimClock to restore into" }
        if (clock.world && clock.world.physics)
            return { error: "the clock is driven by a physics world, whose "
                            + "bodies a snapshot cannot hold" }
        const have = modelStateNames.slice().sort()
        const held = Object.keys(snap.model ?? {}).sort()
        if (have.join("\n") !== held.join("\n"))
            return { error: "the snapshot holds model state [" + held.join(", ")
                            + "], this lab offers [" + have.join(", ") + "]" }

        const notes = []
        const c = snap.clock
        // the seed first: assigning a new one resets the clock, which would
        // wipe whatever came back before it
        if (clock.seed !== c.seed) clock.seed = c.seed
        scenario = snap.scenario ?? ""
        for (const n in snap.params) {
            const par = _params[n]
            if (!par) { notes.push("parameter " + n + " is not in this lab"); continue }
            par._keepDefault()
            par.value = _unpack(snap.params[n])
        }
        for (const n of modelStateNames) _models[n]._load(_unpack(snap.model[n]))

        clock._rngState = c.random
        clock._nextSample = c.nextSample
        clock._stepAccum = c.stepRemainder
        clock._lastStepTime = c.lastStepTime
        clock.time = c.time

        for (const n of probeNames) {
            const pr = _probes[n]
            const e = snap.probes ? snap.probes[n] : undefined
            if (!e) {
                notes.push("probe " + n + " is not in the snapshot")
                pr.clear()
                continue
            }
            const samples = []
            for (let k = 0; k < e.t.length; ++k) samples.push({ t: e.t[k], v: e.v[k] })
            pr.samples = samples
            pr.value = _unpack(e.value)
        }
        for (const n in snap.probes)
            if (!_probes[n]) notes.push("probe " + n + " is not in this lab")

        const recs = snap.recorders ?? []
        for (let k = 0; k < _recorders.length; ++k) {
            const r = _recorders[k]
            if (recs[k]) r._resume(recs[k])
            else if (r.recording && !r._csv) {
                notes.push("a DataRecorder recording to " + r.destination
                           + " starts its record again at the restored time")
                r._restart()
            }
        }

        const log = snap.paramLog ?? ({ start: {}, changes: [] })
        _paramStart = _unpack(log.start)
        _paramLog = _unpack(log.changes)
        restored()
        const r = { restored: true, time: clock.time, scenario: scenario }
        if (notes.length) r.notes = notes
        return r
    }

    /*!
        \qmlmethod var Lab::writeSnapshot(string path, var snap)
        \brief Writes \a snap (default: \l snapshot() now) to \a path as JSON.

        Returns \c {{written: path, bytes}} or \c {{error}}. A relative path
        resolves against the process working directory.

        \sa readSnapshot
    */
    function writeSnapshot(path, snap) {
        snap = snap ?? snapshot()
        if (snap.error) return { error: snap.error }
        const text = JSON.stringify(snap)
        if (!_writer.write(path, text)) return { error: _writer.error }
        return { written: path, bytes: text.length }
    }

    /*!
        \qmlmethod var Lab::readSnapshot(string path)
        \brief Reads a snapshot \l writeSnapshot() wrote, in this process or another.

        Returns the snapshot, ready for \l restore(), or \c {{error}}.
    */
    function readSnapshot(path) {
        const text = _reader.read(path)
        if (_reader.error !== "") return { error: _reader.error }
        try { return JSON.parse(text) }
        catch (e) { return { error: path + " is not JSON: " + e } }
    }

    // A deep copy that JSON carries unchanged: NaN, the infinities and -0,
    // which JSON.stringify turns into null or 0, become {"$num": "..."}.
    function _pack(v) {
        if (typeof v === "number") {
            if (v !== v) return { "$num": "NaN" }
            if (v === Infinity) return { "$num": "Infinity" }
            if (v === -Infinity) return { "$num": "-Infinity" }
            if (v === 0 && 1 / v < 0) return { "$num": "-0" }
            return v
        }
        if (v === null || typeof v !== "object") return v === undefined ? null : v
        if (Array.isArray(v)) {
            const a = new Array(v.length)
            for (let k = 0; k < v.length; ++k) a[k] = _pack(v[k])
            return a
        }
        const o = {}
        for (const k in v) if (typeof v[k] !== "function") o[k] = _pack(v[k])
        return o
    }

    function _unpack(v) {
        if (v === null || typeof v !== "object") return v
        if (Array.isArray(v)) {
            const a = new Array(v.length)
            for (let k = 0; k < v.length; ++k) a[k] = _unpack(v[k])
            return a
        }
        const keys = Object.keys(v)
        if (keys.length === 1 && keys[0] === "$num") {
            const n = v["$num"]
            return n === "-0" ? -0 : Number(n)
        }
        const o = {}
        for (const k of keys) o[k] = _unpack(v[k])
        return o
    }

    /*!
        \qmlmethod var Lab::viewState()
        \brief JSON-serializable lab state for the live-loader reload convention.

        Returns \c {{ scenario, time, params, paramLog, snapshot, flows }}:
        the current scenario name (key omitted while empty), the sim-clock
        time, every registered parameter value, the parameter changes since
        the clock's last reset (\c {{start, changes}}, see \l snapshot()), -
        when the lab's model offers state - a \l snapshot(), and - while a
        lesson runs - \c flows, each running \l Flow's \l {Flow::state()}
        {state()} under its \c flowId. Sandbox roots
        merge their own camera/toggle state on top and hand the result to the
        dojo, which re-applies it after the next reload.

        The loader's inspector leaves \c snapshot out of the view state it
        shows in a \c snapshot response or a flag: it is there for the reload.

        \sa applyViewState
    */
    function viewState() {
        const params = {}
        for (const n of paramNames) params[n] = _params[n].value
        const s = { time: clock ? clock.time : 0, params: params,
                    paramLog: { start: _pack(_paramStart), changes: _pack(_paramLog) } }
        if (scenario !== "") s.scenario = scenario
        if (modelStateNames.length) {
            const snap = snapshot()
            if (!snap.error) s.snapshot = snap
        }
        const flows = {}
        let anyFlow = false
        for (const id in _flows) {
            const f = _flows[id].state()
            if (f) { flows[id] = f; anyFlow = true }
        }
        if (anyFlow) s.flows = flows
        return s
    }

    /*!
        \qmlmethod void Lab::applyViewState(var s)
        \brief Restores parameters and sim time - from the snapshot, else by replay - then the running lessons.

        Ordering contract: the Sandbox root MUST apply \c s.scenario BEFORE
        calling this. The scenario apply resets the clock + RNG.

        With a \c s.snapshot (a lab whose model offers state) the run is
        \l restore()d from it: what it costs does not grow with sim time. A
        snapshot that does not restore - a code edit renamed a ModelState,
        say - is reported and the run is replayed instead.

        Without one, and only when a SimClock exists, is world-less and
        s.time > 0, the run is replayed: the clock is re-stepped to s.time in
        fixed 1/60 s increments from the parameter values it had at its last
        reset, and each parameter change in \c s.paramLog is applied at the
        first step at or after the sim time it was made at - a replay that
        applied the last values from the start ran a different experiment.
        The replay re-runs the causal chain (takeSamples -> sampled ->
        sensors/filter); a run that was frame-driven comes back on the 1/60 s
        grid. World-driven (Box2D) clocks cannot be synchronously re-stepped
        and are left untouched. A payload without \c paramLog sets
        \c s.params and re-steps.

        Then each flow in \c s.flows is \l {Flow::load()}{loaded}: the
        lesson that ran is at the step it was at, without that step's demo
        running again.

        \sa viewState, snapshot
    */
    function applyViewState(s) {
        if (!s) return
        _applyRun(s)
        // the lesson last: its step stands on the lab the run put back
        if (s.flows) {
            for (const id in s.flows) {
                if (_flows[id]) _flows[id].load(s.flows[id])
                else console.warn("Lab: the view state's flow " + id + " is gone")
            }
        }
    }

    function _applyRun(s) {
        if (s.snapshot && modelStateNames.length) {
            if (s.params) for (const n in s.params) set(n, s.params[n])
            let r
            try { r = restore(s.snapshot) }
            catch (e) { r = { error: "" + e } }
            if (!r.error) return
            console.warn("Lab: the view state's snapshot was not restored ("
                         + r.error + ") - replaying the run instead")
            if (clock) clock.reset()
        }
        _replay(s)
    }

    function _replay(s) {
        const log = s.paramLog
        if (!log) {
            if (s.params) for (const n in s.params) set(n, s.params[n])
        } else {
            const start = _unpack(log.start) ?? ({})
            for (const n in start) if (_params[n]) set(n, start[n])
        }
        if (clock && (clock.world === null || clock.world === undefined) && s.time > 0) {
            const changes = log ? _unpack(log.changes) ?? [] : []
            let k = 0
            const due = function () {
                while (k < changes.length && changes[k][0] <= clock.time + 1e-9) {
                    if (_params[changes[k][1]]) set(changes[k][1], changes[k][2])
                    ++k
                }
            }
            due()
            while (clock.time < s.time - 1e-9) { clock._advance(1 / 60); due() }
        }
        // the values the run ended with, whatever the log missed
        if (log && s.params) for (const n in s.params) set(n, s.params[n])
    }
}
