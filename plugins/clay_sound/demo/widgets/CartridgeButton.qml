// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// "Cartridge" preset button. Looks like a slot-in game cart, clicks to
// load a whole scene. Selected state shows the cart half-inserted.

import QtQuick

Item {
    id: root

    property string label: "CART"
    property bool   selected: false
    property color  accent: Retro.amber
    // Optional two-letter tag drawn in the upper-left corner like a
    // cartridge identifier ("01", "MX", etc.).
    property string tag: ""

    signal clicked

    implicitWidth: 120
    implicitHeight: 30

    Rectangle {
        id: body
        anchors.fill: parent
        anchors.topMargin: root.selected ? 0 : 2
        color: root.selected ? "#1a2033" : "#0f1424"
        border.width: 1
        border.color: root.selected ? root.accent : Retro.bevelHi
        radius: 2

        // Top lip — the "slot edge"
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: root.selected ? root.accent : Retro.panelHi
            radius: 1
            opacity: 0.8
        }

        // Cartridge notch (bottom)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.35
            height: 2
            color: Retro.panelLo
        }

        // Tag
        Text {
            visible: root.tag.length > 0
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.topMargin: 4
            text: root.tag
            color: root.selected ? root.accent : Retro.txtDark
            font.family: Retro.mono
            font.pixelSize: Retro.fsLabel
            font.bold: true
        }

        // Label
        Text {
            anchors.centerIn: parent
            text: root.label
            color: root.selected ? "#ffffff" : Retro.txt
            font.family: Retro.mono
            font.pixelSize: Retro.fsValue
            font.bold: root.selected
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
