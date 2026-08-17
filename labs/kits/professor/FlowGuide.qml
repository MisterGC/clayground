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

    /*! Whether the professor speaks the step text or only shows it. */
    property bool spoken: false

    /*! True while the professor is on its way to this step's subject. */
    readonly property bool moving: root.professor ? root.professor.travelling : false

    // --- what happens when ----------------------------------------------------

    onRunningChanged: {
        if (!root.professor)
            return
        if (root.running) {
            root.professor.appear()
            // The step handler does the rest. It is not called from here: a
            // flow sets `running` and `step` in an order this object does not
            // control, and doing the arrival twice looks like a stutter.
            _resume.restart()
        } else {
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
        if (!p || !root.running || root.step < 0)
            return

        const s = (typeof root.subjectOf === "function") ? root.subjectOf(root.step) : null
        const stand = s && s.stand ? s.stand : null
        const look = s && s.look ? s.look : null

        // Say it first and travel while saying it. The alternative - land,
        // then speak - leaves a silent second on every step, and a teacher
        // who is walking is usually already talking.
        root._speak()

        if (stand && p.present) {
            _pending = look
            p.travelTo(stand)
        } else {
            _pending = null
            if (look) p.pointAt(look)
            else p.stopGesture()
        }
    }

    function _speak() {
        const p = root.professor
        if (!p) return
        if (root.text === "") { p.quiet(); return }
        if (root.spoken) p.say(root.text)
        else p.tell(root.text)
    }

    // What to point at once the flight is over. Held rather than pointed at
    // straight away because a gesture solved before take-off is a gesture
    // aimed from the wrong place - see Professor.travelTo().
    property var _pending: null

    Connections {
        target: root.professor
        enabled: root.professor !== null

        function onArrived(at) {
            if (!root.running)
                return
            if (root._pending)
                root.professor.pointAt(root._pending)
            root._pending = null
        }
    }

    // A lab that changes the text without changing the step - a translation
    // switched mid-flow, a step whose line depends on a measurement - should
    // still have the bubble follow.
    onTextChanged: if (root.running && root.step >= 0) root._speak()
}
