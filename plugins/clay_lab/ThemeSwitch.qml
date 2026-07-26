// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ThemeSwitch
    \inqmlmodule Clayground.Lab
    \brief A button that swaps the lab between the light and dark palette.

    Drop it into a corner - beside \l LangSwitch is the convention - and the
    whole lab follows, chrome and board alike, because every colour it paints
    is a binding on \l LabTheme.

    Example usage:
    \qml
    import Clayground.Lab

    Row {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 12; spacing: 6
        LangSwitch { }
        ThemeSwitch { }
    }
    \endqml

    \sa LabTheme, LangSwitch
*/
Rectangle {
    id: _switch

    implicitWidth: 26
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    color: _area.containsMouse ? LabTheme.paperDeep : LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth

    // Sun and moon rather than a word: the control has to explain itself in
    // both languages the labs ship, and it is 26 pixels wide.
    Item {
        anchors.centerIn: parent
        width: 14; height: 14

        // The sun's disc; in dark mode a second disc bites a crescent out of
        // it, which is the whole moon glyph - one shape, two states.
        Rectangle {
            id: _disc
            anchors.centerIn: parent
            width: LabTheme.dark ? 13 : 8
            height: width
            radius: width / 2
            color: LabTheme.dark ? LabTheme.highlight : "transparent"
            border.color: LabTheme.dark ? LabTheme.highlight : LabTheme.inkSoft
            border.width: 2
            Behavior on width { NumberAnimation { duration: 140 } }
        }

        Rectangle {   // the bite that turns the disc into a crescent
            visible: LabTheme.dark
            x: 1; y: -3
            width: 12; height: 12
            radius: width / 2
            color: _switch.color
        }

        Repeater {    // the sun's rays
            model: 8
            Rectangle {
                required property int index
                visible: !LabTheme.dark
                width: 2; height: 3
                radius: 1
                color: LabTheme.inkSoft
                x: 7 - width / 2 + 6.2 * Math.cos(index * Math.PI / 4)
                y: 7 - height / 2 + 6.2 * Math.sin(index * Math.PI / 4)
            }
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: LabTheme.toggle()
    }
}
