// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype TransportChip
    \inqmlmodule Clayground.Lab
    \brief Sim time, pause and speed - the clock, on screen.

    No lab showed its clock, which is a strange gap in a framework whose whole
    claim is determinism: "the same seed and the same stepped frames" is the
    contract, and until now nothing told the learner what time it was.

    Three parts in one chip: the sim-time readout, a pause toggle, and a speed
    cycle. It drives \c SimClock.timeScale from the outside rather than owning
    any clock state, so a lab that also binds a \c simSpeed parameter to the
    same clock keeps working - the chip simply reads back whatever the scale
    now is.

    Pausing sets \c timeScale to 0, which is the kernel's pause verb, and
    resuming restores the speed that was running before - not 1x, because a
    pause taken during a 4x run is meant to be resumed at 4x.

    \qml
    TransportChip {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: LabTheme.spaceXl
    }
    \endqml

    \sa SimClock, Lab
*/
Rectangle {

    // The clock is a readout. Focus mode takes it with the
    // rest of the HUD - see LabView::focus.
    id: root

    /*!
        \qmlproperty var TransportChip::clock
        \brief The SimClock; the active one by default.
    */
    property var clock: Lab.clock

    /*!
        \qmlproperty var TransportChip::speeds
        \brief The speed rungs the button cycles.
    */
    property var speeds: [0.25, 0.5, 1, 2, 4]

    /*!
        \qmlproperty int TransportChip::digits
        \brief Decimals on the time readout.
    */
    property int digits: 1

    /*!
        \qmlproperty bool TransportChip::showSpeed
        \brief Offer the speed cycle.
    */
    property bool showSpeed: true

    /*!
        \qmlproperty bool TransportChip::paused
        \readonly
        \brief The clock is standing still.
    */
    readonly property bool paused: clock !== null && clock !== undefined
                                   && clock.timeScale === 0

    // the speed to come back to; never 0, or resume would resume nothing
    property real _resumeAt: 1

    /*!
        \qmlmethod void TransportChip::toggle()
        \brief Pause or resume.
    */
    function toggle() {
        if (!clock) return
        if (paused) clock.timeScale = _resumeAt > 0 ? _resumeAt : 1
        else { _resumeAt = clock.timeScale; clock.timeScale = 0 }
    }

    /*!
        \qmlmethod void TransportChip::cycleSpeed()
        \brief Next speed rung, resuming if paused.
    */
    function cycleSpeed() {
        if (!clock) return
        const cur = paused ? _resumeAt : clock.timeScale
        let next = speeds[0]
        for (let i = 0; i < speeds.length; ++i)
            if (speeds[i] > cur + 1e-6) { next = speeds[i]; break }
        _resumeAt = next
        clock.timeScale = next
    }

    visible: clock !== null && clock !== undefined && !LabView.focus
    implicitWidth: _row.width + 2 * LabTheme.spaceXl
    implicitHeight: LabTheme.px(28)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: LabTheme.spaceL

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // "t" and a number: language-neutral, and the same symbol the
            // papers use for sim time
            text: "t " + LabLang.num(root.clock ? root.clock.time : 0, root.digits) + " s"
            color: LabTheme.ink
            font.pixelSize: LabTheme.fontBody; font.bold: true
            font.family: LabTheme.monoFont
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.paused ? "▶" : "❚❚"
            color: root.paused ? LabTheme.tertiary : LabTheme.secondary
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
            TapHandler { onTapped: root.toggle() }
        }

        Text {
            visible: root.showSpeed
            anchors.verticalCenter: parent.verticalCenter
            text: LabLang.num(root.paused ? root._resumeAt
                                          : (root.clock ? root.clock.timeScale : 1), 2) + "×"
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
            TapHandler { onTapped: root.cycleSpeed() }
        }
    }
}
