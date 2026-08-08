// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ModeChip
    \inqmlmodule Clayground.Lab
    \brief Build, explore or measure, on screen - and clickable.

    The mode is the one piece of lab state that changes what the \e mouse
    means, so it may not be invisible: a learner whose drag suddenly moves the
    scene instead of drawing a road has to be able to see why. Same contract
    as \l GridMode - the surface shows the mode - one level up, where the
    surface is the chrome.

    It reads and drives an \c OrbitInput3D (\c mode, \c allowedModes,
    \c cycleMode()), naming the mode it is in and cycling on a click, exactly
    as its key does. A lab that offers only one mode hides it
    (\c modeSwitchable), where a control that can only ever say one thing is
    noise - and a lab that offers two shows the same chip, since which two
    they are is the lab's business, not the chip's.

    While the mode is sprung - Space held - the chip says \e explore like any
    other explore, because that is what the mouse is doing; the key hint is
    what tells you it is temporary. A measurement taken before the key went
    down is still there when it comes up: the run outlives the borrowed
    camera, and only the sticky mode ends it.

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

    /*! \qmlproperty bool ModeChip::measuring \readonly \brief The pointer is in measure mode. */
    readonly property bool measuring: pointer ? pointer.measuring === true : false

    /*! \qmlproperty string ModeChip::mode \readonly \brief The mode being shown. */
    readonly property string mode: exploring ? "explore" : measuring ? "measure" : "build"

    visible: pointer !== null && pointer !== undefined
             && pointer.modeSwitchable === true

    implicitWidth: _row.width + 2 * LabTheme.spaceXl
    implicitHeight: LabTheme.px(24)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    // Build is the resting look of every other chip; the two modes that took
    // the mouse away from it are filled in, and in different inks, because
    // "the drag moves the view" and "the click drops a point" are two
    // different surprises.
    color: exploring ? LabTheme.secondary
         : measuring ? LabTheme.primary
         : LabTheme.panel
    border.color: mode === "build" ? LabTheme.panelEdge : color
    border.width: LabTheme.borderWidth
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
            text: root.exploring ? "✋" : root.measuring ? "📏" : "✎"
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
}
