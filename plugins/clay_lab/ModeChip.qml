// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ModeChip
    \inqmlmodule Clayground.Lab
    \brief Build or explore, on screen - and clickable.

    The mode is the one piece of lab state that changes what the \e mouse
    means, so it may not be invisible: a learner whose drag suddenly moves the
    scene instead of drawing a road has to be able to see why. Same contract
    as \l GridMode - the surface shows the mode - one level up, where the
    surface is the chrome.

    It reads and drives an \c OrbitInput3D (\c mode, \c exploring,
    \c toggleMode()), and hides itself for a lab that has nothing to build
    (\c modeLocked), where a control that can only ever say one thing is
    noise.

    While the mode is sprung - Space held - the chip says \e explore like any
    other explore, because that is what the mouse is doing; the key hint is
    what tells you it is temporary.

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

    /*! \qmlproperty bool ModeChip::exploring \readonly \brief What the pointer is doing right now. */
    readonly property bool exploring: pointer ? pointer.exploring === true : false

    visible: pointer !== null && pointer !== undefined && pointer.modeLocked !== true

    implicitWidth: _row.width + 2 * LabTheme.spaceXl
    implicitHeight: LabTheme.px(24)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    // Explore is the state that CHANGED the mouse, so explore is the state
    // that is filled in; build is the resting look of every other chip.
    color: exploring ? LabTheme.secondary : LabTheme.panel
    border.color: exploring ? LabTheme.secondary : LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: LabTheme.spaceM

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // a hand for the mode that grabs the world, a pen for the one that
            // draws on it - the same two verbs the modes are named after
            text: root.exploring ? "✋" : "✎"
            color: LabTheme.inkOn(root.color)
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: LabLang.t(root.exploring ? "mode.explore" : "mode.build")
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
        onTapped: if (root.pointer) root.pointer.toggleMode()
    }
}
