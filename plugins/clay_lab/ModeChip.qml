// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ModeChip
    \inqmlmodule Clayground.Lab
    \brief Whether the pointer is building, on screen - and clickable.

    Building is the one piece of lab state that changes what the \e mouse
    means, so it may not be invisible: a learner whose drag suddenly moves the
    scene instead of drawing a road has to be able to see why. Same contract
    as \l GridMode - the surface shows the mode - one level up, where the
    surface is the chrome.

    It shows \e one thing because there is only one thing to show. There were
    briefly three modes here (build, explore, measure) and the chip named
    whichever was on; measuring is now an instrument in the hand rather than a
    mode, so what is left is a toggle: building, or not. An empty hand gets no
    label at all - it is an absence, and naming it would be inventing a state.
    What is in the hand, when something is, is the \l InstrumentBelt's to show.

    A lab with nothing to build hides the chip (\c modeSwitchable), where a
    control that can only ever say one thing is noise.

    While the mode is sprung - Space held - the chip goes quiet like any other
    non-building moment, because that is what the mouse is doing; the key hint
    is what tells you it is temporary.

    \qml
    Row {
        ModeChip { pointer: nav }
        LangSwitch {}
    }
    \endqml

    \sa GridMode, LabKeys
*/
Rectangle {
    id: root

    /*! \qmlproperty var ModeChip::pointer \brief The \c OrbitInput3D whose mode this shows. */
    property var pointer: null

    /*! \qmlproperty string ModeChip::key \brief The key that toggles it, for the hint. */
    property string key: "B"

    /*! \qmlproperty bool ModeChip::building \readonly \brief The pointer belongs to the lab's own tool. */
    readonly property bool building: pointer ? pointer.effectiveMode === "build" : false

    /*! \qmlproperty string ModeChip::mode \readonly \brief The mode being shown. */
    readonly property string mode: building ? "build" : "use"

    visible: pointer !== null && pointer !== undefined
             && pointer.modeSwitchable === true

    implicitWidth: _row.width + 2 * LabTheme.spaceXl
    implicitHeight: LabTheme.px(24)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    // Filled while the lab's tool owns the mouse, quiet while the camera does:
    // the loud state is the one with a surprise in it.
    color: building ? LabTheme.primary : LabTheme.panel
    border.color: building ? color : LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    opacity: building ? 1 : 0.8
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: LabTheme.spaceM

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // a hand for the mode that grabs the world, a pen for the one that
            // draws on it, a rule for the one that asks how far - the same
            // verbs the modes are named after
            text: root.building ? "✎" : "✋"
            color: LabTheme.inkOn(root.color)
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: LabLang.t("mode." + root.mode)
            color: LabTheme.inkOn(root.color)
            font.pixelSize: LabTheme.fontLabel; font.bold: true
            font.family: LabTheme.handFont
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.key
            color: LabTheme.inkOn(root.color)
            opacity: 0.55
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    TapHandler {
        onTapped: if (root.pointer) root.pointer.cycleMode()
    }

    // The label is the mode's own name while building and the plain camera
    // otherwise; both are short, and neither invents a state.
}
