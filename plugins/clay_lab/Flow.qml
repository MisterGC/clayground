// (c) Clayground Contributors - MIT License, see "LICENSE" file
// SPIKE (lab-flows groundwork, awaiting review): shape may still change.

import QtQuick

/*!
    \qmltype Flow
    \inqmlmodule Clayground.Lab
    \brief A narrated walkthrough that drives the lab through its own mutation API.

    A flow is an ordered list of \l FlowStep. Demonstration steps run the
    lab's own verbs (from the lab's \c flowActions() map) so the learner sees
    the lab being operated; task steps wait for a condition on lab state.
    Pacing is measured in \e sim seconds, so a flow traverses the same states
    live and headless, and \c SimClock.timeScale scales it.

    While a flow runs the board is the flow's, and a task lends back exactly
    the one interaction it asks for - see \l control. That is the whole
    difference between a lesson and a demo somebody can walk over: the
    professor cannot explain the current that flows while a second click is
    reopening the switch.

    Example usage:
    \qml
    import Clayground.Lab

    Flow {
        id: flow
        lab: root; flowId: "led-basics"
        FlowStep {
            key: "place"
            demo: [["let", "bat", "addPart", "battery", 6, 2]]
        }
        FlowStep {
            key: "flip"
            task: { "until": (n) => root.elemAt(n("sw")).on,
                    "allow": ["sw"],          // the one thing that is live
                    "solve": [["flipSwitch", "sw"]] }
        }
    }
    \endqml

    \sa FlowStep, Narrator, LabLang
*/
Item {
    id: _flow

    /*!
        \qmlproperty list<FlowStep> Flow::steps
        \brief The steps (default property).
    */
    default property list<FlowStep> steps

    /*!
        \qmlproperty var Flow::lab
        \brief The sandbox root: source of \c flowActions() and of the checkpoints.
    */
    property var lab: null

    /*!
        \qmlproperty var Flow::camera
        \brief The lab's camera rig, for steps that carry a \l {FlowStep::view}.

        An \l OrbitCamera3D (anything with \c goTo / \c focusOn / \c applyState
        will do). Left null, \c FlowStep.view is ignored - which is the whole
        of the compatibility story: a flow that never wires a camera behaves
        exactly as it did before the property existed.
    */
    property var camera: null

    /*!
        \qmlproperty string Flow::flowId
        \brief Stable id; prefixes narration keys and identifies the flow.
    */
    property string flowId: ""

    /*!
        \qmlproperty string Flow::titleKey
        \brief Dictionary key of the flow's title.
    */
    property string titleKey: ""

    /*!
        \qmlproperty int Flow::index
        \brief Active step, -1 while the flow is not running.
    */
    property int index: -1

    /*!
        \qmlproperty bool Flow::running
        \readonly
    */
    readonly property bool running: index >= 0
    /*!
        \qmlproperty string Flow::control
        \readonly
        \brief Who has the board right now: \c "learner", \c "flow" or \c "task".

        A lesson alternates the way a game tutorial does. While no flow runs
        the board is the \c learner's and everything works. The moment one
        starts it is the \c flow's: it is building and explaining, and a
        touch on the board is refused rather than obeyed. A task step opens
        exactly what it named (\l {FlowStep::task}{task.allow}) and nothing
        else - that is \c task - and the instant its \c until holds the
        board is the flow's again. Full control comes back by leaving the
        flow (\l stop()), not by touching something mid-lesson.

        \sa grants(), refusal
    */
    readonly property string control: !running ? "learner" : (waiting ? "task" : "flow")

    /*!
        \qmlproperty string Flow::refusal
        \brief LabLang key of why the last touch did nothing; "" again after a moment.

        The refusal channel of a locked board, and the reason locking one is
        not the same as ignoring the learner: a click that does nothing and
        says nothing reads as a broken lab. \l Narrator renders it.

        \sa refuse()
    */
    property string refusal: ""
    /*!
        \qmlproperty bool Flow::waiting
        \readonly
        \brief In a task: the learner must act.
    */
    readonly property bool waiting: running && step !== null && step.task !== null
    /*!
        \qmlproperty bool Flow::pending
        \readonly
        \brief Waiting on the learner or on the sim.
    */
    readonly property bool pending: waiting || (running && step !== null && step.watch !== null)
    /*!
        \qmlproperty bool Flow::hintShown
        \readonly
    */
    property bool hintShown: false

    /*!
        \qmlproperty var Flow::unresolvedVerbs
        \readonly
        \brief Verb names a demo or a solve asked for and the lab does not have.

        Cleared by \l start(). A verb that does not resolve fails SILENTLY -
        the action does nothing and the flow walks on teaching nothing - so a
        headless run has to be able to read the list rather than hope somebody
        was watching the log.

        \sa Lab::runFlow
    */
    property var unresolvedVerbs: []

    /*!
        \qmlproperty string Flow::pacing
        \brief How a step ends: "ready" (default), "auto" or "manual".

        \c ready uses the reading estimate as a \e ripening time, not as an
        advance: while it runs the Next control is quiet, and when it elapses
        Next becomes prominent and the learner confirms. Nobody is hurried and
        nobody waits - Next stays clickable throughout, so a learner who
        already knows this step can skip straight past it.

        \c auto advances by itself once the estimate elapses (kiosk mode,
        recordings, and the headless verification run); \c manual offers no
        estimate at all.

        A task step is the exception in every mode: it ends when its
        \c until holds (or \l solve is asked for), never on a Next - the
        \l Narrator offers none while \l waiting - so no later line can
        assume the learner did something they did not.
    */
    property string pacing: "ready"

    /*!
        \qmlproperty real Flow::dwellTarget
        \readonly
        \brief Sim seconds this step is estimated to need (0 while waiting).
    */
    readonly property real dwellTarget:
        (step === null || step.task || step.watch) ? 0 : dwellOf(step)

    /*!
        \qmlproperty real Flow::readySince
        \readonly
        \brief 0..1 progress through the estimate; 1 means "read it, go on".
    */
    readonly property real readyProgress:
        dwellTarget <= 0 ? 1 : Math.min(1, stepTime / dwellTarget)

    /*!
        \qmlproperty bool Flow::ripe
        \readonly
        \brief The estimate has elapsed: Next is the obvious thing to do now.
    */
    readonly property bool ripe: readyProgress >= 1
    /*!
        \qmlproperty FlowStep Flow::step
        \readonly
    */
    readonly property FlowStep step: index >= 0 && index < steps.length ? steps[index] : null
    /*!
        \qmlproperty string Flow::title
        \readonly
    */
    readonly property string title: titleKey === "" ? "" : LabLang.t(titleKey)

    /*!
        \qmlproperty var Flow::marks
        \readonly
        \brief The active step's \l {FlowStep::mark} names; empty when idle.

        One binding for the lab: hand it to whatever resolves and draws the
        marks (the professor kit's \c FlowGuide, or a \l MarkLayer
        directly). It empties itself when the flow stops, so a mark cannot
        outlive the lesson.
    */
    readonly property var marks: (step === null || !step.mark) ? [] : step.mark

    /*!
        \qmlproperty string Flow::narration
        \readonly
        \brief The active step's text in the current language.
    */
    readonly property string narration: {
        LabLang.lang            // re-narrate when the language changes
        return step === null ? "" : sayOf(step)
    }

    /*! \qmlsignal Flow::narrated(string text, string lang, string key) */
    signal narrated(string text, string lang, string key)
    /*! \qmlsignal Flow::finished() */
    signal finished()

    property real stepTime: 0        // sim seconds spent in this step
    property var _names: ({})        // flow-local part names -> lab ids
    // step index -> { view: lab viewState, names: the name table as it stood }.
    // The names belong in the checkpoint, not beside it: a later step refers to
    // what an earlier one bound ("let bat"), so entering a step from its
    // checkpoint has to restore the bindings that step was written against.
    // Otherwise a jump into the middle of a flow leaves every name unresolved
    // and each demo verb operates on the literal string instead - which fails
    // silently, because a lab verb given an unknown id simply does nothing.
    property var _checkpoints: ({})

    /*!
        \qmlmethod void Flow::start()
        \brief Starts at the first step, dropping earlier checkpoints.
    */
    function start() {
        _checkpoints = ({}); _names = ({})
        unresolvedVerbs = []
        refusal = ""
        goTo(0)
    }

    /*!
        \qmlmethod void Flow::stop()
        \brief Leaves the flow - and hands the whole board back, at once.
    */
    function stop() { index = -1; hintShown = false; refusal = "" }

    /*! \qmlmethod void Flow::next() */
    function next() {
        if (index + 1 >= steps.length) { stop(); finished() }
        else goTo(index + 1)
    }

    /*! \qmlmethod void Flow::prev() */
    function prev() { if (index > 0) goTo(index - 1) }

    /*!
        \qmlmethod void Flow::goTo(int i)
        \brief Jumps to a step: restores its checkpoint, then replays its demo.

        Every step is entered from a stored lab state, so stepping back or
        scrubbing never has to replay the whole flow.
    */
    function goTo(i) {
        if (i < 0 || i >= steps.length) { stop(); return }
        const cp = _checkpoints[i]
        if (cp !== undefined && lab && lab.applyViewState) {
            _names = _clone(cp.names)
            lab.applyViewState(_clone(cp.view))
        } else if (lab && lab.viewState) {
            _checkpoints[i] = { view: _clone(lab.viewState()), names: _clone(_names) }
        }
        index = i
        stepTime = 0
        hintShown = false
        refusal = ""
        const s = steps[i]
        if (s.demo && s.demo.length) run(s.demo)
        applyView(s.view)          // after the demo: a step may frame what it built
        narrated(narration, LabLang.lang, s.key)
    }

    /*!
        \qmlmethod void Flow::applyView(var v)
        \brief Moves \l camera as a \l {FlowStep::view} asks; a no-op without one.
    */
    function applyView(v) {
        if (!v || !camera) return
        if (v.viewpoint !== undefined && camera.goTo) camera.goTo(v.viewpoint, v.ms)
        else if (v.focus !== undefined && camera.focusOn) camera.focusOn(v.focus, v.pad, v.ms)
        else if (v.pose !== undefined && camera.applyState) camera.applyState(v.pose)
    }

    /*!
        \qmlmethod void Flow::replayStep()
        \brief Re-enters the current step from its checkpoint.
    */
    function replayStep() { const i = index; index = -1; goTo(i) }

    /*!
        \qmlmethod void Flow::solve()
        \brief Performs the current task for the learner ("show me").
    */
    function solve() {
        if (step && step.task && step.task.solve) run(step.task.solve)
    }

    /*!
        \qmlmethod bool Flow::grants(var id)
        \brief May the learner touch part \a id right now?

        True whenever no flow runs. While one does, only during a task step
        and only for what that task's \c allow named - resolved through
        \l nameOf, so a task names the part the way its \c until and its
        \c solve do (\c {"allow": ["sw"]}). A task whose subject only exists
        once its own demo has run gives a function instead
        (\c {"allow": (n) => root.logicInputs}), evaluated per press. A task
        that names nothing keeps the whole board live, which is what every
        flow written before this existed still gets.
    */
    function grants(id) {
        if (!running) return true
        const s = step
        if (!s || !s.task) return false
        let a = s.task.allow
        if (a === undefined || a === null) return true
        if (typeof a === "function") a = a(nameOf)
        if (a === undefined || a === null) return true
        for (const x of a) if (nameOf(x) === id) return true
        return false
    }

    /*!
        \qmlmethod void Flow::refuse()
        \brief Says why the touch just refused did nothing, for a moment.
    */
    function refuse() {
        refusal = control === "task" ? "flow.refuse.task" : "flow.refuse.busy"
        _refuseTimer.restart()
    }

    /*!
        \qmlmethod bool Flow::check()
        \brief Re-tests the running task's \c until at once; advances if it holds.

        The clock samples ten times a second, which is late enough for a
        second click to land on a task the first one already satisfied - the
        exact thing a locked board exists to stop. Whoever performed a granted
        interaction calls this the moment the gesture is over, so the board is
        the flow's again before the next press can arrive.
    */
    function check() {
        if (!running || !waiting) return false
        const s = step
        if (!s.task.until || !s.task.until(nameOf)) return false
        next()
        return true
    }

    property Timer _refuseTimer: Timer {
        interval: 2200
        onTriggered: _flow.refusal = ""
    }

    /*!
        \qmlmethod string Flow::sayOf(QtObject step)
        \brief Narration for a step: dictionary entry for its key, else \c say.
    */
    function sayOf(s) {
        if (!s) return ""
        if (s.key !== "" && flowId !== "") {
            const k = "flow." + flowId + "." + s.key
            const t = LabLang.t(k)
            if (t !== k) return t
        }
        return s.say
    }

    // The lab's verbs. A flow can only do what a user could do.
    function verbs() {
        return (lab && lab.flowActions) ? lab.flowActions() : ({})
    }
    function nameOf(n) { return _names[n] !== undefined ? _names[n] : n }

    // A checkpoint has to be a snapshot, not a view: the lab keeps mutating the
    // object it handed over, and _names keeps growing as later steps bind.
    function _clone(o) { return JSON.parse(JSON.stringify(o)) }

    /*!
        \qmlmethod void Flow::run(var actions)
        \brief Executes an action list against the lab's verbs.
    */
    function run(actions) {
        const vs = verbs()
        for (const a of actions) {
            if (!a || a.length === 0) continue
            let verb = a[0], args = a.slice(1), bind = null
            if (verb === "let") { bind = args[0]; verb = args[1]; args = args.slice(2) }
            const fn = vs[verb]
            if (!fn) {
                console.warn("Flow: lab has no verb '" + verb + "'")
                unresolvedVerbs = unresolvedVerbs.concat([verb])
                continue
            }
            const out = fn.apply(null, args.map(x => nameOf(x)))
            if (bind !== null) _names[bind] = out
        }
    }

    // Reading time beats a fixed dwell: it already matches speech, so a
    // recorded or synthesized voice can replace the estimate later.
    function dwellOf(s) {
        if (!s) return 0
        if (s.dwell !== "auto") return Number(s.dwell)
        const words = sayOf(s).split(/\s+/).length
        return Math.max(2.5, words / 2.2)
    }

    // Filed with the kernel so Lab.runFlow() can find it by id. Registration
    // follows Parameter's rule - the moment the id is known, not at completion
    // - because a lab's own Component.onCompleted runs before its children's.
    Component.onCompleted: _register()
    Component.onDestruction: Lab.unregisterFlow(_flow)
    onFlowIdChanged: _register()

    property string _registered: ""

    function _register() {
        if (flowId === _registered) return
        if (_registered !== "") Lab.unregisterFlowNamed(_registered, _flow)
        _registered = flowId
        if (flowId !== "") Lab.registerFlow(_flow)
    }

    // Sim-time driven, never a wall clock: same states live and headless.
    property Connections _tick: Connections {
        target: Lab
        enabled: _flow.running
        function onSampled(t) {
            const s = _flow.step
            if (!s) return
            const dt = Lab.clock ? Lab.clock.sampleInterval : 0.1
            _flow.stepTime += dt
            if (s.watch) {
                // the sim gets there on its own; the learner just watches
                if (s.watch.until && s.watch.until(_flow.nameOf)) _flow.next()
                return
            }
            if (s.task) {
                // check() is also what a granted interaction calls the moment
                // it is done, so this is the backstop rather than the only
                // route out of a task
                if (_flow.check()) return
                const after = s.task.hintAfter !== undefined ? s.task.hintAfter : 6
                if (!_flow.hintShown && _flow.stepTime > after) _flow.hintShown = true
                return
            }
            // "ready" pacing never advances on its own - the estimate only
            // ripens the Next control (see Flow::pacing)
            if (_flow.pacing === "auto" && _flow.stepTime >= _flow.dwellOf(s))
                _flow.next()
        }
    }
}
