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

    implicitWidth: LabTheme.px(26)
    implicitHeight: LabTheme.px(26)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    color: _area.containsMouse ? LabTheme.paperDeep : LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth

    // Sun and moon rather than a word: the control has to explain itself in
    // both languages the labs ship, and it is barely more than a font size
    // wide. The glyph is laid out in units of its own box, so the whole thing
    // grows with the scale instead of rattling around inside a bigger chip.
    Item {
        id: _glyph
        anchors.centerIn: parent
        width: LabTheme.px(14); height: width

        // The sun's disc; in dark mode a second disc bites a crescent out of
        // it, which is the whole moon glyph - one shape, two states.
        Rectangle {
            id: _disc
            anchors.centerIn: parent
            width: _glyph.width * (LabTheme.dark ? 0.93 : 0.57)
            height: width
            radius: width / 2
            color: LabTheme.dark ? LabTheme.highlight : "transparent"
            border.color: LabTheme.dark ? LabTheme.highlight : LabTheme.inkSoft
            border.width: Math.max(1, LabTheme.px(2))
            Behavior on width { NumberAnimation { duration: 140 } }
        }

        Rectangle {   // the bite that turns the disc into a crescent
            visible: LabTheme.dark
            x: _glyph.width * 0.07; y: -_glyph.height * 0.21
            width: _glyph.width * 0.86; height: width
            radius: width / 2
            color: _switch.color
        }

        Repeater {    // the sun's rays
            model: 8
            Rectangle {
                required property int index
                visible: !LabTheme.dark
                width: Math.max(1, _glyph.width * 0.14)
                height: Math.max(1, _glyph.height * 0.21)
                radius: width / 2
                color: LabTheme.inkSoft
                x: _glyph.width / 2 - width / 2
                   + _glyph.width * 0.44 * Math.cos(index * Math.PI / 4)
                y: _glyph.height / 2 - height / 2
                   + _glyph.height * 0.44 * Math.sin(index * Math.PI / 4)
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
