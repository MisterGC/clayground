// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Compact 2-letter jump label for vim-style "f" jump mode.
// Caller drives `jumpActive` and `activePrefix`; the label dims when
// the prefix doesn't match.

import QtQuick

Rectangle {
    id: root
    property string code: ""
    property string activePrefix: ""
    property bool   jumpActive: false

    visible: jumpActive
    opacity: (activePrefix === "" || code.indexOf(activePrefix) === 0) ? 1.0 : 0.25
    z: 1000
    width: 22
    height: 14
    radius: 2
    color: Retro.amber
    border.color: Retro.bevelHi
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: parent.code
        color: "#0a0f1a"
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: true
    }
}
