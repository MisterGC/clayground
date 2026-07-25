// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype LangSwitch
    \inqmlmodule Clayground.Lab
    \brief A row of language chips driving \l {LabLang}::lang.

    Drop it into a corner of a lab that ships more than one language; it
    offers exactly the languages the registered dictionaries know about and
    hides itself while there is only one.

    Example usage:
    \qml
    import Clayground.Lab

    LangSwitch { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12 }
    \endqml

    \sa LabLang
*/
Row {
    id: _switch

    /*!
        \qmlproperty var LangSwitch::languages
        \brief Language codes to offer (defaults to every registered one).
    */
    property var languages: LabLang.languages

    visible: languages.length > 1
    spacing: 6

    Repeater {
        model: _switch.languages
        Rectangle {
            id: _chip
            required property string modelData
            readonly property bool active: modelData === LabLang.lang
            width: 38; height: 26
            radius: LabTheme.radius
            color: _chip.active ? LabTheme.secondary : LabTheme.panel
            border.color: _chip.active ? LabTheme.secondary : LabTheme.panelEdge
            border.width: LabTheme.borderWidth
            Text {
                anchors.centerIn: parent
                text: LabLang.langName(_chip.modelData)
                color: _chip.active ? LabTheme.paper : LabTheme.inkSoft
                font.pixelSize: 12; font.bold: _chip.active
                font.letterSpacing: 0.5
                font.family: LabTheme.monoFont
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: LabLang.lang = _chip.modelData
            }
        }
    }
}
