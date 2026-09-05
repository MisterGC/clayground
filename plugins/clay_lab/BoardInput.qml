// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

/*!
    \qmltype BoardInput
    \inqmlmodule Clayground.Lab
    \brief The mouse on a \l Board: wire pads, select and drag parts, operate, erase, tap a wire.

    The whole left-button gesture of a build lab, and the rule it lives by:
    \b {the left button is always the board's}. Navigation never competes
    for it - the camera (\l nav) is asked first and with its default buttons
    the answer for the left button is always no; then the hand (\l hands): an
    instrument out means the click is the instrument's. Only then is the
    press the board's, and what it does depends on what \l Board::hitAt found:

    \list
    \li nothing - clears the selection (and a dangling wire, unless erasing);
    \li with the eraser on - removes the wire or the part, at once;
    \li a wire - taps it: a junction is dropped there and the wire splits,
        so a branch can start anywhere;
    \li a terminal - starts a wire, or ends the dangling one;
    \li an actuator - selects the part first, operates it on the \e second
        click (\l operate fires on release, so a press that turns into a
        camera drag flips nothing);
    \li a body - selects and starts a drag.
    \endlist

    With a \l flow wired, that whole list is conditional: while a lesson runs
    the board is the flow's, and only what the running task named answers at
    all.

    The gesture lives in named functions (\l pressAt, \l moveAt, \l releaseAt,
    \l clickAt, \l dragFrom) rather than in the signal handlers, so a flow, a
    test or an agent can perform the SAME drag a hand does - the inspector can
    synthesize a click but not a drag. A right \e click walks back one step
    (hand, dangling wire, eraser, selection - in that order); a right drag
    still turns the view and cancels nothing.

    \qml
    BoardInput {
        id: boardMouse
        board: board; nav: nav; hands: hands; stage: stage; view: view3d; grid: grid
        flow: root.currentFlow                 // while it runs, the board is its
        onOperate: (id) => root.toggleSwitch(id)
    }
    \endqml

    \sa Board, OrbitInput3D, InstrumentBelt, GridMode, Flow
*/
MouseArea {
    id: root

    /*! \qmlproperty Board BoardInput::board */
    property var board: null
    /*! \qmlproperty var BoardInput::nav \brief The \c OrbitInput3D; asked first about every press. */
    property var nav: null
    /*! \qmlproperty var BoardInput::hands \brief The \l InstrumentBelt; asked second. Optional. */
    property var hands: null
    /*! \qmlproperty var BoardInput::stage \brief The \l LabStage3D, for \c worldAt. */
    property var stage: null
    /*! \qmlproperty var BoardInput::view \brief The View3D the stage projects through. */
    property var view: null
    /*! \qmlproperty var BoardInput::grid \brief A \l GridMode; Alt inverts it for one drag. Optional. */
    property var grid: null

    /*!
        \qmlproperty var BoardInput::flow
        \brief The lab's \l Flow. While one runs, it decides what the board answers to.

        A lesson explains, hands over exactly the interaction it asked for,
        takes the board back when that is done, and continues. With a flow
        wired here that rule is the mouse's: a press is checked against
        \l {Flow::grants()} before anything happens, a refused press says so
        through \l {Flow::refuse()} instead of quietly doing nothing, and
        hovering an inert part promises nothing - no highlight, no pointing
        hand. Left null, every press is the learner's, which is what a lab
        without a flow (and every flow written before this) gets.
    */
    property var flow: null

    /*!
        \qmlproperty bool BoardInput::gated
        \readonly
        \brief A flow is running, so it - not the learner - says what is live.
    */
    readonly property bool gated: flow !== null && flow !== undefined && flow.running

    /*!
        \qmlproperty real BoardInput::dragSlop
        \brief World units a press must travel before it is a drag.
    */
    property real dragSlop: 1.2

    /*!
        \qmlsignal BoardInput::operate(int id)
        \brief The selected part's actuator was clicked: the domain decides what operating means.
    */
    signal operate(int id)
    /*!
        \qmlsignal BoardInput::interacted()
        \brief A part was selected or operated - a touch that was allowed through.

        Not emitted for a press a running \l flow refused: those did not
        happen as far as the lab is concerned.
    */
    signal interacted()

    /*!
        \qmlmethod bool BoardInput::granted(var hit)
        \brief Whether a running \l flow lets the learner touch what \a hit found.

        Everything, with no flow running. With one: only a part the current
        task named, and only \e as a part - a pad or a wire is the circuit
        the lesson is teaching, and rewiring it mid-sentence is the thing
        this exists to stop.
    */
    function granted(hit) {
        if (!gated) return true
        if (!hit) return false
        if (hit.kind === "wire" || hit.kind === "terminal") return false
        return flow.grants(hit.el)
    }

    /*!
        \qmlproperty var BoardInput::hintKeys
        \brief The LabLang keys the \l hint line is built from; a lab overrides the wording by key.
    */
    property var hintKeys: ({
        eraser: "hint.eraser", actuator: "hint.actuator", actuatorPick: "hint.actuator.pick",
        wiring: "hint.wiring", selected: "hint.selected", selectedSnap: "hint.selected.snap",
        selectedFree: "hint.selected.free", selectedFrame: "hint.selected.frame", idle: "hint.idle"
    })

    readonly property bool handEmpty: !hands || hands.empty

    /*!
        \qmlproperty bool BoardInput::hoverActuator
        \readonly
        \brief The cursor is over the SELECTED part's actuator - the next click operates it.

        Drives the cursor, the part's own highlight and the hint bar, so the
        three cannot say different things. Only once it is the selected part:
        before that the click selects, and a cursor promising a flip would be
        describing the click after next.
    */
    readonly property bool hoverActuator:
        board !== null && board.hoverHit !== null && board.hoverHit.kind === "actuator"
        && !board.eraser && handEmpty && board.selectedId === board.hoverHit.el

    /*!
        \qmlproperty bool BoardInput::hoverActuatorIdle
        \readonly
        \brief Over an operable part that is not the one being worked on - the next click selects it.
    */
    readonly property bool hoverActuatorIdle:
        board !== null && board.hoverHit !== null && board.hoverHit.kind === "actuator"
        && !board.eraser && handEmpty && board.selectedId !== board.hoverHit.el

    /*!
        \qmlproperty string BoardInput::hint
        \readonly
        \brief The hint-bar line for the current state, translated.
    */
    readonly property string hint: {
        if (!board) return ""
        // the hand outranks everything: while an instrument is out, a hint
        // about clicking pads describes something you are not doing
        if (hands && !hands.empty) return LabLang.t(hands.held.hint)
        if (board.eraser) return LabLang.t(hintKeys.eraser)
        // Above wiring on purpose: pointing at an actuator while a wire is
        // half-drawn is the exact moment the two get confused
        if (hoverActuator) return LabLang.t(hintKeys.actuator)
        if (hoverActuatorIdle) return LabLang.t(hintKeys.actuatorPick)
        if (board.wiringFrom) return LabLang.t(hintKeys.wiring)
        if (board.selectedId !== -1)
            return LabLang.t(hintKeys.selected)
                 + LabLang.t(!grid || grid.snap ? hintKeys.selectedSnap : hintKeys.selectedFree)
                 + LabLang.t(hintKeys.selectedFrame)
        return LabLang.t(hintKeys.idle)
    }

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    // A pointing hand is the one cursor everybody already reads as "this
    // does something when you click it".
    cursorShape: hoverActuator && !pressed ? Qt.PointingHandCursor
               : (nav ? nav.cursorShape : Qt.ArrowCursor)

    property var dragElem: null
    // The part being operated by this press, if any.
    property var actuateElem: null
    property bool dragged: false
    property var pressW: null

    function snapping(mods) { return grid ? grid.snapping(mods) : true }
    /*! \qmlmethod var BoardInput::worldAt(real mx, real my) \brief The board point under a window point, or null. */
    function worldAt(mx, my) { return stage ? stage.worldAt(view, mx, my) : null }

    /*! \qmlmethod void BoardInput::moveAt(real mx, real my, int mods, bool isDown) */
    function moveAt(mx, my, mods, isDown) {
        if (isDown && nav && nav.active) { nav.move(mx, my); return }
        if (isDown && hands && hands.held) { hands.move(mx, my); return }
        if (!isDown && nav) nav.hoverAt(mx, my)
        const w = worldAt(mx, my)
        if (!w) return
        board.cursorW = Qt.vector3d(w.x, board.cursorHeight, w.z)
        if (isDown && dragElem) {
            if (!dragged && pressW && Math.hypot(w.x - pressW.x, w.z - pressW.z) > dragSlop)
                dragged = true
            if (dragged)
                board.movePart(dragElem, board.colOf(w.x), board.rowOf(w.z), snapping(mods))
        } else {
            // An inert part must not light up under the cursor: the highlight
            // and the pointing hand both read off hoverHit, so a refused hit
            // is no hit at all.
            const h = board.hitAt(w.x, w.z)
            board.hoverHit = granted(h) ? h : null
        }
    }

    /*! \qmlmethod void BoardInput::clickAt(real x, real y, int mods) \brief A click, as one call. */
    function clickAt(x, y, mods) {
        pressAt(x, y, Qt.LeftButton, mods || 0)
        releaseAt()
    }
    /*! \qmlmethod void BoardInput::dragFrom(real x1, real y1, real x2, real y2, int mods) \brief A drag, as one call. */
    function dragFrom(x1, y1, x2, y2, mods) {
        pressAt(x1, y1, Qt.LeftButton, mods || 0)
        moveAt(x2, y2, mods || 0, true)
        releaseAt()
    }

    onWheel: (wheel) => { if (nav) nav.wheel(wheel.angleDelta.y, wheel.x, wheel.y) }

    onDoubleClicked: (mouse) => {
        // only over bare board: a double-click on a part belongs to the part
        const w = worldAt(mouse.x, mouse.y)
        if (w && !board.hitAt(w.x, w.z) && nav) nav.recenterAt(mouse.x, mouse.y)
    }

    onPositionChanged: (mouse) => moveAt(mouse.x, mouse.y, mouse.modifiers, pressed)
    onPressed: (mouse) => pressAt(mouse.x, mouse.y, mouse.button, mouse.modifiers)
    onReleased: releaseAt()

    /*! \qmlmethod void BoardInput::pressAt(real mx, real my, int button, int mods) */
    function pressAt(mx, my, button, mods) {
        if (parent) parent.forceActiveFocus()
        if (nav) {
            nav.cancel()
            // Ask the camera first, and with the default buttons the answer
            // for the left button is always no - so nothing below has to
            // think about the camera again, and nothing below can be starved
            // by it.
            if (nav.begin(mx, my, button, mods) !== "") return
        }
        // Then the hand: an instrument out means the click is the
        // instrument's, and it decides click-versus-drag itself.
        if (hands && hands.held) { hands.press(mx, my); return }
        const w = worldAt(mx, my)
        pressW = w; dragged = false; dragElem = null
        const hit = w ? board.hitAt(w.x, w.z) : null
        // Before anything the board would do with it: while a flow runs the
        // board is the flow's, and a task lends back only what it named. A
        // refused press says so rather than doing nothing - one that does
        // nothing and says nothing reads as a broken lab.
        if (gated && !granted(hit)) { flow.refuse(); return }
        // empty board (or off-board): a click there means "nothing"
        if (!hit) {
            board.selectedId = -1
            if (!board.eraser) board.wiringFrom = null
            return
        }
        if (board.eraser) {
            if (hit.kind === "wire") board.removeWire(hit.wire)
            else if (hit.kind === "element" || hit.kind === "terminal")
                board.removePart(hit.el)
            return
        }
        // Clicking a wire taps into it: a junction is dropped where you
        // clicked and the wire splits, so you can branch off anywhere.
        if (hit.kind === "wire") {
            const j = board.splitWireAt(hit.wire, w.x, w.z)
            if (j === -1) return
            if (board.wiringFrom) {
                board.addWire([board.wiringFrom.el, board.wiringFrom.ti], [j, 0])
                board.wiringFrom = null
            } else {
                board.wiringFrom = { el: j, ti: 0 }
            }
            return
        }
        if (hit.kind === "terminal") {
            const el = board.partAt(hit.el)
            // an idle click on a junction grabs the dot itself; while
            // wiring, the same click connects to it
            if (el && el.type === "junction" && board.wiringFrom === null) {
                board.selectedId = hit.el
                dragElem = hit.el
                return
            }
            if (board.wiringFrom === null)
                board.wiringFrom = { el: hit.el, ti: hit.ti }
            else {
                board.addWire([board.wiringFrom.el, board.wiringFrom.ti], [hit.el, hit.ti])
                board.wiringFrom = null
            }
            return
        }
        // Operating a part is its own gesture: no drag, no wire, no change to
        // what is selected. Fired on RELEASE, so a press that turns into a
        // camera drag still does not flip anything. And it is reserved for
        // the part you have SELECTED: first click selects, second operates -
        // the hover affordance says which of the two the next click is.
        if (hit.kind === "actuator") {
            if (board.selectedId !== hit.el) {
                board.selectedId = hit.el
                dragElem = hit.el
                interacted()
                return
            }
            actuateElem = hit.el
            interacted()
            return
        }
        if (hit.kind === "element") {
            board.selectedId = hit.el
            dragElem = hit.el
        }
        interacted()   // the learner is driving now, not the flow
    }

    /*! \qmlmethod void BoardInput::releaseAt() */
    function releaseAt() {
        if (nav) nav.end()          // a flicked drag coasts to a stop from here
        if (hands && hands.release()) return   // the click was the instrument's
        if (actuateElem !== null) {
            operate(actuateElem)
            actuateElem = null
            dragElem = null; dragged = false
            _done()
            return
        }
        // Nothing else operates on release: a part's state is set on its
        // card, or through the actuator once the part is selected.
        dragElem = null; dragged = false
        _done()
    }

    // The gesture is over: if it satisfied the running task, the board goes
    // back to the flow NOW and not at the clock's next sample, which is late
    // enough for a second click to undo what the first one just achieved.
    function _done() { if (gated) flow.check() }

    /*!
        \qmlmethod void BoardInput::cancelAll()
        \brief What Esc does on a board: drops the dangling wire, the eraser and the selection.
    */
    function cancelAll() {
        board.wiringFrom = null; board.eraser = false; board.selectedId = -1
    }

    // A step change can happen while the mouse is standing still - a task ends
    // the instant its `until` holds - and a highlight left under the cursor
    // would go on promising a click the board no longer answers.
    Connections {
        target: root.flow
        enabled: root.flow !== null && root.flow !== undefined
        function onIndexChanged() { if (root.board) root.board.hoverHit = null }
    }

    // A right CLICK is "put it down" - the RTS cancel. It empties the hand and
    // drops whatever the board had half-started, in that order, so one press
    // walks back one step.
    Connections {
        target: root.nav
        function onCancelled() {
            if (root.hands && !root.hands.empty) { root.hands.putAway(); return }
            if (root.board.wiringFrom) { root.board.wiringFrom = null; return }
            if (root.board.eraser) { root.board.eraser = false; return }
            root.board.selectedId = -1
        }
    }
}
