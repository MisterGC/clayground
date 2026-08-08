// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ScaleSwitch
    \inqmlmodule Clayground.Lab
    \brief Makes the whole lab larger or smaller: A-, the current percentage, A+.

    The third member of the corner family, beside \l LangSwitch and
    \l ThemeSwitch, and the one a room full of people asks for first: shown on
    a large screen from a few metres away every control in the chrome was too
    small to read, and there was nothing to turn.

    The middle chip is not decoration - it reads back the factor and resets to
    100% when clicked, which is the only way out of an accidental 200% that
    does not involve finding the keyboard.

    The same three steps are on \c Ctrl+Plus, \c Ctrl+Minus and \c Ctrl+0
    through \l LabKeys, so a lab that instantiates a keymap has them already.

    Example usage:
    \qml
    import Clayground.Lab

    Row {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: LabTheme.spaceXl; spacing: LabTheme.spaceM
        LangSwitch { }
        ScaleSwitch { }
        ThemeSwitch { }
    }
    \endqml

    \sa LabTheme, ThemeSwitch, LangSwitch
*/
Row {
    id: root

    /*! \qmlproperty bool ScaleSwitch::showValue \brief Show the percentage chip between the buttons. */
    property bool showValue: true

    spacing: LabTheme.px(2)

    component Chip: Rectangle {
        id: _chip
        property string label: ""
        property bool enabledStep: true
        signal activated()
        width: Math.max(LabTheme.px(26), _text.implicitWidth + LabTheme.spaceL)
        height: LabTheme.px(26)
        radius: LabTheme.radius
        color: _area.containsMouse && _chip.enabledStep ? LabTheme.paperDeep : LabTheme.panel
        border.color: LabTheme.panelEdge
        border.width: LabTheme.borderWidth
        opacity: _chip.enabledStep ? 1 : 0.45
        Text {
            id: _text
            anchors.centerIn: parent
            text: _chip.label
            // the chip's own fill decides its ink; the palette lifts panel and
            // paperDeep past each other between the two themes
            color: LabTheme.inkOn(_chip.color)
            font.pixelSize: LabTheme.fontBody
            font.bold: true
            font.family: LabTheme.monoFont
        }
        MouseArea {
            id: _area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: _chip.enabledStep ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (_chip.enabledStep) _chip.activated()
        }
    }

    Chip {
        label: "A−"
        enabledStep: LabTheme.uiScale > 0.7501
        onActivated: LabTheme.stepScale(-1)
    }
    Chip {
        visible: root.showValue
        label: LabTheme.scaleLabel
        onActivated: LabTheme.resetScale()
    }
    Chip {
        label: "A+"
        enabledStep: LabTheme.uiScale < 1.9999
        onActivated: LabTheme.stepScale(1)
    }
}
