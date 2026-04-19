// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Chunky two-state sliding toggle. Retro dev-console feel.
//
// Usage:
//   RetroToggle {
//       leftLabel: "MOUSE"
//       rightLabel: "VIM"
//       checked: vimMode           // false = left, true = right
//       onCheckedChanged: vimMode = checked
//   }

import QtQuick

Item {
    id: root

    property string leftLabel:  "OFF"
    property string rightLabel: "ON"
    property bool   checked: false
    property color  leftAccent:  Retro.tealDim
    property color  rightAccent: Retro.pink

    signal toggled(bool v)

    implicitWidth: 130
    implicitHeight: 30

    // Housing
    Rectangle {
        id: housing
        anchors.fill: parent
        color: "#0a0d18"
        border.color: Retro.bevelHi
        border.width: 1
        radius: 2

        // Inner frame
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "#060913"
            border.color: Retro.bevelLo
            border.width: 1
        }
    }

    // LEDs above each label
    Row {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: -6
        spacing: root.width - 10 - 4
        Rectangle {
            width: 4; height: 4; radius: 1
            color: !root.checked ? root.leftAccent : "#2a3246"
            opacity: !root.checked ? 1.0 : 0.5
        }
        Rectangle {
            width: 4; height: 4; radius: 1
            color: root.checked ? root.rightAccent : "#2a3246"
            opacity: root.checked ? 1.0 : 0.5
        }
    }

    // Labels
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.leftLabel
        color: !root.checked ? root.leftAccent : Retro.txtDark
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: !root.checked
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.rightLabel
        color: root.checked ? root.rightAccent : Retro.txtDark
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: root.checked
    }

    // Handle
    Rectangle {
        id: handle
        width: parent.width * 0.42
        height: parent.height - 6
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: "#1a2033"
        border.color: root.checked ? root.rightAccent : root.leftAccent
        border.width: 1
        radius: 2
        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

        // Two horizontal grip lines
        Rectangle { anchors.centerIn: parent; anchors.verticalCenterOffset: -3
            width: parent.width * 0.45; height: 1; color: "#3a4560" }
        Rectangle { anchors.centerIn: parent; anchors.verticalCenterOffset:  3
            width: parent.width * 0.45; height: 1; color: "#3a4560" }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
