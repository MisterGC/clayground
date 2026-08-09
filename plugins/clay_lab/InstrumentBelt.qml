// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Window
import Clayground.Lab

/*!
    \qmltype InstrumentBelt
    \inqmlmodule Clayground.Lab
    \brief What the viewer can pick up: the kernel's instruments in every lab,
    plus whatever the kit brought.

    One line inside a lab's \c View3D and the lab has a tape measure and a
    stopwatch:

    \qml
    View3D {
        OrbitInput3D { id: nav; rig: rig; view: view3d }
        InstrumentBelt { id: hands; pointer: nav; unit: "m" }
    }
    \endqml

    A ruler you have to install first is a ruler nobody reaches for, so the
    kernel's instruments are here by default rather than declared per lab; a
    kit's own instrument is declared inside the belt and joins the same row:

    \qml
    InstrumentBelt {
        pointer: nav
        Voltmeter { circuit: sim }
    }
    \endqml

    \section2 It owns the one input that changes meaning

    The belt is the only thing that writes \c {OrbitInput3D::picking}, and it
    writes it for exactly one reason: something is in the hand. Every
    navigation gesture is untouched either way - that is the whole contract, and
    keeping it in one place is what stops it drifting. The instruments
    themselves never see the pointer; they are handed picks.

    \section2 Coordinates

    It fills its parent, which is the \c View3D, so its children draw in view
    coordinates and an instrument's screen-space overlay lines up with the
    scene without any mapping of its own.

    \sa HandheldInstrument, TapeMeasure, Stopwatch, OrbitInput3D
*/
Item {
    id: root

    anchors.fill: parent

    /*! \qmlproperty var InstrumentBelt::pointer \brief The \c OrbitInput3D whose picks feed the hand. */
    property var pointer: null

    /*! \qmlproperty var InstrumentBelt::view \brief The \c View3D; defaults to the pointer's. */
    property var view: pointer ? pointer.view : null

    /*!
        \qmlproperty string InstrumentBelt::unit
        \brief The unit this lab's world is in: \c "m", \c "mm", \c "u" ...

        The kernel cannot know - one lab's cell is a metre of tarmac and
        another's a millimetre of board - so the lab says, once, and the
        instruments that measure lengths follow.
    */
    property string unit: "u"

    /*!
        \qmlproperty bool InstrumentBelt::defaults
        \brief Carry the kernel's own instruments. On, and rarely off.
    */
    property bool defaults: true

    /*!
        \qmlproperty var InstrumentBelt::instruments
        \readonly
        \brief Everything on the belt: the kernel's, then the kit's, in order.
    */
    readonly property var instruments: {
        const out = []
        if (defaults) { out.push(_tape); out.push(_watch) }
        // Declared children are the kit's contribution - duck-typed rather
        // than declared in a second list, so adding one to a lab is one line
        // in one place.
        for (let i = 0; i < children.length; ++i) {
            const c = children[i]
            if (!c || c === _tape || c === _watch) continue
            if (c.pickKind !== undefined && c.pin !== undefined) out.push(c)
        }
        return out
    }

    /*! \qmlproperty int InstrumentBelt::heldIndex \brief Which instrument is in hand; -1 for none. */
    property int heldIndex: -1

    /*! \qmlproperty var InstrumentBelt::held \readonly \brief The instrument in hand, or null. */
    readonly property var held: heldIndex >= 0 && heldIndex < instruments.length
                                ? instruments[heldIndex] : null

    /*! \qmlproperty bool InstrumentBelt::empty \readonly \brief The hand is empty. */
    readonly property bool empty: held === null

    /*! \qmlproperty string InstrumentBelt::key \brief The key that cycles the belt, for hints. */
    property string key: "H"

    /*! \qmlproperty string InstrumentBelt::pinKey \brief The key that keeps a reading. */
    property string pinKey: "P"

    /*!
        \qmlproperty real InstrumentBelt::rowMargin
        \brief How far above the bottom of the view the belt sits.

        Defaults to just clear of a \l HintBar. A lab with more bottom chrome
        than that - sensor-fusion parks a full-width plot down there - raises
        it, because the belt has to be visible to be a belt.
    */
    property real rowMargin: LabTheme.px(26) + 2 * LabTheme.spaceL

    /*! \qmlmethod void InstrumentBelt::take(int i) \brief Puts instrument \a i in the hand. */
    function take(i) {
        heldIndex = (i >= 0 && i < instruments.length) ? i : -1
    }

    /*! \qmlmethod void InstrumentBelt::takeNamed(string n) \brief Takes the instrument called \a n. */
    function takeNamed(n) {
        for (let i = 0; i < instruments.length; ++i)
            if (instruments[i].name === n) { take(i); return true }
        return false
    }

    /*! \qmlmethod void InstrumentBelt::putAway() \brief Empties the hand. */
    function putAway() { heldIndex = -1 }

    /*!
        \qmlmethod void InstrumentBelt::cycle()
        \brief Next instrument, then back to an empty hand.

        Empty is a position on the belt, not the absence of one: cycling past
        the last instrument puts everything down, which is how you get the
        plain camera back without hunting for a key.
    */
    function cycle() {
        heldIndex = heldIndex + 1 >= instruments.length ? -1 : heldIndex + 1
    }

    /*! \qmlmethod var InstrumentBelt::info() \brief The belt as plain values, for an agent or a test. */
    function info() {
        return { held: held ? held.name : null,
                 names: instruments.map(i => i.name),
                 reading: held ? held.info() : null }
    }

    // The one write that changes what an input means. Declarative, so it can
    // never be left switched on by a code path that forgot.
    Binding {
        target: root.pointer
        property: "picking"
        value: root.held !== null
        when: root.pointer !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Connections {
        target: root.pointer
        ignoreUnknownSignals: true
        function onPicked(pick) { if (root.held) root.held.add(pick) }
        // Building and holding an instrument are the two claims on the same
        // click, so they cannot both be true: entering build puts whatever was
        // in the hand away.
        function onModeChanged() {
            if (root.pointer.mode === "build") root.putAway()
        }
    }

    // ...and the other direction. Taking an instrument out is already the
    // decision to use it, so it hands the pointer over rather than leaving a
    // state where something is in the hand and a click still builds - which is
    // a dead tool with a hint bar describing it. One key, one intent.
    //
    // This is the ONLY coupling between the hand and the mode, and it is not a
    // mode switch in disguise: every navigation gesture is identical on both
    // sides of it. What changes is only who gets the short click.
    onHeldChanged: {
        if (held && pointer && pointer.allows && pointer.allows("use"))
            pointer.setMode("use")
    }

    // Instruments are handed their context rather than reaching for it: that
    // is what keeps "no camera code in an instrument" true.
    function _sync() {
        const list = instruments
        for (let i = 0; i < list.length; ++i) {
            list[i].view = root.view
            list[i].held = (i === heldIndex)
        }
    }
    onHeldIndexChanged: _sync()
    onInstrumentsChanged: _sync()
    onViewChanged: _sync()
    Component.onCompleted: _sync()

    // --- the kernel's own ---------------------------------------------------

    TapeMeasure { id: _tape; unit: root.unit; visible: root.defaults }
    Stopwatch { id: _watch; visible: root.defaults }

    // --- keeping a reading --------------------------------------------------

    /*! \qmlproperty bool InstrumentBelt::pinning \readonly \brief The name prompt is open. */
    readonly property alias pinning: _prompt.visible

    /*!
        \qmlmethod bool InstrumentBelt::beginPin()
        \brief Opens the name prompt for the reading in hand.

        The name is asked for rather than generated because it becomes a column
        in the run record, and a run record is what a paper cites: \c dist_1 is
        a bad citation forever. The suggestion is pre-filled and Enter takes
        it, so the fast path is still one key.
    */
    function beginPin() {
        if (!held || !held.pinnable) return false
        _prompt.text = held.suggestedName()
        _prompt.focusBack = _prompt.Window.activeFocusItem
        _prompt.visible = true
        _field.forceActiveFocus()
        _field.selectAll()
        return true
    }

    /*! \qmlmethod void InstrumentBelt::cancelPin() \brief Closes the prompt, keeping nothing. */
    function cancelPin() { _prompt.close() }

    /*! \qmlmethod bool InstrumentBelt::commitPin() \brief Keeps the reading under the typed name. */
    function commitPin() {
        const ok = root.held ? root.held.pin(_field.text.trim()) : false
        _prompt.close()
        return ok
    }

    Rectangle {
        id: _prompt
        property string text: ""
        property var focusBack: null
        function close() {
            visible = false
            if (focusBack) focusBack.forceActiveFocus()
            focusBack = null
        }

        visible: false
        anchors.centerIn: parent
        width: _pin.width + 2 * LabTheme.spaceXl
        height: _pin.height + 2 * LabTheme.spaceL
        radius: LabTheme.radius
        color: LabTheme.panel
        border.color: LabTheme.primary
        border.width: LabTheme.borderWidth

        Column {
            id: _pin
            anchors.centerIn: parent
            spacing: LabTheme.spaceM

            Text {
                text: LabLang.t("hand.pin.ask")
                color: LabTheme.ink
                font.pixelSize: LabTheme.fontLabel
                font.family: LabTheme.handFont
            }
            Rectangle {
                width: LabTheme.px(220)
                height: LabTheme.px(28)
                radius: LabTheme.radius
                color: LabTheme.paper
                border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                TextInput {
                    id: _field
                    anchors.fill: parent
                    anchors.leftMargin: LabTheme.spaceM
                    verticalAlignment: TextInput.AlignVCenter
                    text: _prompt.text
                    color: LabTheme.ink
                    font.pixelSize: LabTheme.fontLabel
                    font.family: LabTheme.monoFont
                    selectByMouse: true
                    onAccepted: root.commitPin()
                    Keys.onEscapePressed: root.cancelPin()
                }
            }
            Text {
                text: LabLang.t("hand.pin.hint")
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
        }
    }

    // --- the belt itself ----------------------------------------------------
    // Above the hint bar, centred: it is chrome about the pointer, and the
    // pointer is everywhere.

    Row {
        id: _row
        visible: root.instruments.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.rowMargin
        spacing: LabTheme.spaceM

        Repeater {
            model: root.instruments.length
            delegate: Rectangle {
                required property int index
                readonly property var inst: root.instruments[index]
                readonly property bool mine: root.heldIndex === index

                height: LabTheme.px(24)
                width: _chip.width + 2 * LabTheme.spaceL
                radius: LabTheme.radius
                color: mine ? inst.tone : LabTheme.panel
                border.color: mine ? inst.tone : LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                opacity: mine ? 1 : 0.75
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: _chip
                    anchors.centerIn: parent
                    spacing: LabTheme.spaceS
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.inst.glyph
                        color: LabTheme.inkOn(parent.parent.color)
                        font.pixelSize: LabTheme.fontSmall
                        font.family: LabTheme.monoFont
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.inst.label
                        color: LabTheme.inkOn(parent.parent.color)
                        font.pixelSize: LabTheme.fontLabel
                        font.bold: parent.parent.mine
                        font.family: LabTheme.handFont
                    }
                    // the reading rides on the chip once there is one, so the
                    // belt doubles as the readout for an instrument with no
                    // place of its own in the scene
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: parent.parent.mine ? parent.parent.inst.valueText : ""
                        color: LabTheme.inkOn(parent.parent.color)
                        font.pixelSize: LabTheme.fontSmall
                        font.family: LabTheme.monoFont
                    }
                }

                TapHandler {
                    onTapped: root.heldIndex === index ? root.putAway() : root.take(index)
                }
            }
        }

        // The key that walks the belt, on the belt - a control nobody can find
        // is a control the lab does not have.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.key
            color: LabTheme.inkFaint
            opacity: 0.7
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }
}
