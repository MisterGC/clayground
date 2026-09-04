// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// FlowGuide - hands a lab's guided flow to the professor.
//
// A flow already knows what to say and in what order. What it cannot do is
// the thing a teacher does without thinking: walk over to the thing being
// discussed and put a finger on it. This is the wiring between the two, and
// it is deliberately a component rather than a page of Connections in every
// lab that wants one.
//
// The split it keeps: the kit knows how a professor narrates - arrive, fly,
// point, speak, leave, and in what order, with the waits in the right places.
// Only the lab knows WHERE step four's subject is. So the lab supplies one
// function, `subjectOf`, and gets the rest.
//
// It observes the flow rather than driving it. Everything here is a reaction
// to `running`, `step` and `text`, which the lab binds to whatever its flow
// calls those - so no flow has to grow a professor-shaped hook, and turning
// the professor off is deleting this object.

import QtQuick
import Clayground.Character3D
import Clayground.Lab

Item {
    id: root

    // Nothing to draw.
    visible: false
    width: 0
    height: 0

    /*! The Professor to drive. Null does nothing at all. */
    property var professor: null

    /*! True while the flow is running. Bind it to the flow. */
    property bool running: false

    /*! Which step is current, counting from 0. Bind it to the flow. */
    property int step: -1

    /*! What the current step says. Bind it to the flow. */
    property string text: ""

    /*!
        The lab's half. Given a step index, return where the professor should
        stand and what it should point at:

        \code
        subjectOf: (i) => ({ stand: Qt.vector3d(x, 0, z),
                             look:  Qt.vector3d(x, y, z) })
        \endcode

        Either field may be omitted: no \c stand means "say it from where you
        are", no \c look means "say it without pointing at anything". Return
        null for a step that wants neither - a step about the whole board, or
        one that is only a question for the reader.
    */
    property var subjectOf: null

    /*!
        Where the professor is standing when it appears, as a \c vector3d.
        Null leaves it wherever it already is.

        It is placed there rather than flown there: it is not in the scene
        yet, and a character that materialises at the origin and then
        commutes to the lesson has told the reader that the origin means
        something. It does not.
    */
    property var entrance: null

    /*! Whether the professor speaks the step text or only shows it. */
    property bool spoken: false

    /*!
        The lab's other half: given a step index, the url of the narration
        clip for it, or "" for a step that has none.

        \code
        voiceOf: (i) => Qt.resolvedUrl("voice/en/" + keyOf(i) + ".wav")
        \endcode

        Same split as \l subjectOf - only the lab knows where its audio is,
        and whether it has any. Missing files are not an error: a step with no
        clip is narrated in text, exactly as before, so a half-recorded flow
        still runs.
    */
    property var voiceOf: null

    /*!
        Whether the professor lets go of the point partway through a step,
        turns to the camera and talks the rest of it out with its hands.

        On by default, and it is the difference between a teacher and a
        signpost. Pointing is deixis: it means "this one", it has said that
        within a second or two, and a finger held on a part for the length of
        a paragraph stops being a gesture and becomes a fixture. What follows
        a point is explanation, and people deliver explanation to a face.

        False keeps the finger on the part for the whole step - for a lab
        whose steps are one short label each, where there is nothing after
        the deixis to turn around for.
    */
    property bool addressViewer: true

    /*!
        How long the point is held, in milliseconds, before the professor
        turns to the reader. Negative means "as long as the step's first
        sentence takes to read", which is the default and is what the beat
        actually wants: the point belongs to "this is the transistor", not to
        the three sentences about what it does.
    */
    property int pointHoldMs: -1

    /*!
        Optional: given a step index, a performance script for it, or "" for
        a step narrated the built-in way.

        \code
        scriptOf: (i) => i === 0
            ? "*point at the bench* This is where we start. (2500ms)"
              + " *face viewer* Every lesson begins here."
            : ""
        \endcode

        A step with a script is DIRECTED rather than narrated: after the
        professor lands, the script plays through a \l Performance and the
        built-in beat - speak, point, hold, address - stands aside for that
        step. The step's \c text is ignored too, since the script carries its
        own lines. Steps without a script keep the built-in choreography, so
        a flow can direct only the steps that earn it.
    */
    property var scriptOf: null

    /*!
        Where \c{*point at NAME*} looks names up: a scene node whose tree is
        searched for a matching \c objectName - typically the View3D's scene.
        Only needed by flows whose scripts point at things.
    */
    property var scriptTargets: null

    /*!
        The lab's own name lookup for script targets, when \c objectName is
        not how its scene is organized: \c{function(name)} returning a
        world-space \c vector3d or null. A circuit lab whose parts are data
        rather than named nodes answers "the resistor" from its model here.
        Set, it replaces the \l scriptTargets walk entirely.
    */
    property var scriptResolve: null

    /*!
        The audio twin of \l scriptOf: \c{function(step, sayIndex)} returning
        a clip url for the \c sayIndex-th spoken line of that step's script,
        or "" for a line narrated by mouth alone. This is per LINE where
        \l voiceOf is per STEP, because a directed step usually speaks more
        than once - a pointed line and an addressed one are two recordings.
    */
    property var scriptVoiceOf: null

    /*! The step's director. Exposed for state assertions (\c{guide.script.done}). */
    readonly property Performance script: _perf

    Performance {
        id: _perf
        performer: root.professor
        searchRoot: root.scriptTargets
        resolveTarget: root.scriptResolve
        voiceOf: (sayIndex) => (typeof root.scriptVoiceOf === "function")
                 ? root.scriptVoiceOf(root.step, sayIndex) : ""
        spoken: false
        viewerPosition: () => {
            const p = root.professor
            return p && p.view && p.view.camera ? p.view.camera.scenePosition : null
        }
    }

    function _scriptFor(step) {
        const s = (typeof root.scriptOf === "function") ? root.scriptOf(step) : ""
        return s === undefined || s === null ? "" : "" + s
    }

    /*! True once the professor has let go of the point and is addressing the reader. */
    readonly property bool addressing: _addressing

    /*! True while the professor is on its way to this step's subject. */
    readonly property bool moving: root.professor ? root.professor.travelling : false

    // --- what happens when ----------------------------------------------------

    onRunningChanged: {
        // Lab.headless is a run with no audience: no arrival, no flight, no
        // narration clip. The professor is the slowest thing in a lesson and
        // none of it is state the flow's own checks look at.
        if (!root.professor || Lab.headless)
            return
        if (root.running) {
            if (root.entrance)
                root.professor.stand = root.entrance
            root.professor.appear()
            // The step handler does the rest. It is not called from here: a
            // flow sets `running` and `step` in an order this object does not
            // control, and doing the arrival twice looks like a stutter.
            _resume.restart()
        } else {
            _hold.stop()
            _perf.stop()
            _addressing = false
            root.professor.stopGesture()
            root.professor.vanish()
        }
    }

    onStepChanged: _resume.restart()

    // One tick of slack. A flow changing step usually changes several
    // properties, and reacting to the first of them means flying off to the
    // subject of a step whose text has not arrived yet.
    Timer {
        id: _resume
        interval: 1
        onTriggered: root._go()
    }

    function _go() {
        const p = root.professor
        if (!p || !root.running || root.step < 0 || Lab.headless)
            return

        const s = (typeof root.subjectOf === "function") ? root.subjectOf(root.step) : null
        const stand = s && s.stand ? s.stand : null
        const look = s && s.look ? s.look : null

        _hold.stop()
        _perf.stop()
        _addressing = false

        // A directed step: the flight still happens - only the lab knows
        // where to stand - but everything after landing belongs to the
        // script, not to the built-in beat.
        const script = root._scriptFor(root.step)
        if (script !== "") {
            if (stand && p.present) {
                _pending = null
                _pendingScript = script
                p.quiet()
                p.travelTo(stand)
            } else {
                _pendingScript = ""
                _perf.play(script)
            }
            return
        }
        _pendingScript = ""

        if (stand && p.present) {
            // Fly first, then talk. Talking on the way over sounds like the
            // natural thing - a teacher crossing a room is usually already
            // mid-sentence - and it is wrong here, because the line is what
            // every other piece of timing is measured against. Spend three
            // seconds of a nine-second line in the air and the point on
            // arrival gets what is left, which can be nothing: the professor
            // lands, raises a finger, and the mouth stops. The flight is
            // silent, and the sentence starts where the sentence is about.
            _pending = look
            p.quiet()
            p.travelTo(stand)
        } else {
            _pending = null
            root._speak()
            if (look) root._point(look)
            else root._address()
        }
    }

    // Point at it, and start the clock on how long that stays interesting.
    function _point(look) {
        root.professor.pointAt(look)
        if (!root.addressViewer)
            return
        _hold.interval = root.pointHoldMs >= 0 ? root.pointHoldMs
                                               : root._firstSentenceMs()
        _hold.restart()
    }

    // Let go, turn round, keep talking. Also the whole of a step that has
    // nothing to point at: standing still and reciting is the thing this
    // component exists to avoid.
    function _address() {
        const p = root.professor
        if (!p) return
        _addressing = true
        p.faceViewer()
        // Only if there is still something being said. Hands that talk while
        // the mouth is shut are worse than no hands: turning to the reader is
        // worth doing on its own, gesticulating at them is not.
        if (p.talking)
            p.gesticulate()
    }

    property bool _addressing: false

    // How long the point on the step's subject is worth holding: as long as
    // the opening sentence, which is the part of the line the pointing is
    // about.
    //
    // The clamp matters more than the rate: under it the professor snatches
    // its hand back before the reader has followed the finger, and over it we
    // are back to the signpost.
    //
    // And it is capped as a SHARE of the whole line, which is the part that
    // was wrong. A one-sentence step is a line whose first sentence is all of
    // it, so the hold used to run to the end of the speech and the turn landed
    // after the mouth had already stopped: the professor mouthed the line at
    // the board, then swung round and gesticulated in silence. Whatever the
    // sentence arithmetic says, the turn happens while there is still
    // something being said.
    readonly property int _holdMinMs: 1200
    readonly property int _holdMaxMs: 3600
    readonly property real _holdShare: 0.55

    function _firstSentenceMs() {
        const p = root.professor
        const rate = p && p.speechRateMs ? p.speechRateMs : 72
        const m = /[.!?](\s|$)/.exec(root.text)
        const n = m ? m.index + 1 : root.text.length
        let ms = Math.min(root._holdMaxMs, n * rate)
        // The professor knows the real length once a clip has loaded; the
        // estimate is only a stand-in for it.
        const whole = p && p.talking && p.lineMs > 0 ? p.lineMs : root.text.length * rate
        return Math.max(root._holdMinMs, Math.min(ms, whole * root._holdShare))
    }

    Timer {
        id: _hold
        onTriggered: if (root.running) root._address()
    }

    function _speak() {
        const p = root.professor
        if (!p) return
        if (root.text === "") { p.quiet(); return }
        if (root.spoken) { p.say(root.text); return }
        const clip = (typeof root.voiceOf === "function") ? root.voiceOf(root.step) : ""
        p.tell(root.text, clip)
    }

    // What to point at once the flight is over. Held rather than pointed at
    // straight away because a gesture solved before take-off is a gesture
    // aimed from the wrong place - see Professor.travelTo().
    property var _pending: null

    // Same reason, for a directed step: the script's own points are solved
    // where the professor lands, so it must not start in the air.
    property string _pendingScript: ""

    Connections {
        target: root.professor
        enabled: root.professor !== null

        function onArrived(at) {
            if (!root.running)
                return
            if (root._pendingScript !== "") {
                _perf.play(root._pendingScript)
                root._pendingScript = ""
                root._pending = null
                return
            }
            // Speak BEFORE pointing, not after: the hold on the point is a
            // share of how long the line lasts, and the professor only knows
            // that once the line has been given to it.
            root._speak()
            if (root._pending)
                root._point(root._pending)
            else
                root._address()
            root._pending = null
        }
    }

    // A lab that changes the text without changing the step - a translation
    // switched mid-flow, a step whose line depends on a measurement - should
    // still have the bubble follow. Not while travelling, though: that is the
    // one moment the professor is deliberately silent, and arriving speaks the
    // current text anyway.
    onTextChanged: {
        if (!root.running || root.step < 0 || Lab.headless)
            return
        if (root.professor && root.professor.travelling)
            return
        // A directed step's lines come from its script; the flow's text is
        // not part of that performance and must not talk over it.
        if (root._scriptFor(root.step) !== "")
            return
        root._speak()
    }
}
