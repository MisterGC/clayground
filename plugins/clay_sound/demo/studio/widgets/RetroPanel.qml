// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Beveled dark-chrome panel frame with an optional header strip + LED
// dots. Use as the outer container for slots, transport, tracker.
//
// Usage:
//   RetroPanel {
//       title: "S1 KICK"
//       Item { ... }              // body content inherits panel size
//   }

import QtQuick

Item {
    id: root

    property string title: ""
    property color  titleColor: Retro.amber
    property alias  body: bodyContainer
    // When true, a row of amber LED dots is drawn in the title strip —
    // purely decorative "powered-on" vibe.
    property bool   showLeds: true
    property int    ledCount: 4
    property int    activeLeds: ledCount
    // When > 0 the panel gets a subtle scanline overlay.
    property real   scanlineAlpha: 0.04

    readonly property int titleH: title.length > 0 ? 24 : 0

    // Outer bezel
    Rectangle {
        anchors.fill: parent
        color: Retro.panel
        border.color: Retro.bevelHi
        border.width: 1
        radius: 3
    }
    // Inner bevel (dark lip) for that embossed look
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: "transparent"
        border.color: Retro.bevelLo
        border.width: 1
        radius: 2
    }
    // Corner screws — faux hex-head bolts in each corner sell the
    // "rack-mounted hardware" vibe.
    Repeater {
        model: [[6, 6], [6, -6], [-6, 6], [-6, -6]]
        Rectangle {
            x: modelData[0] >= 0 ? modelData[0] : root.width + modelData[0] - 3
            y: modelData[1] >= 0 ? modelData[1] : root.height + modelData[1] - 3
            width: 3; height: 3; radius: 0
            color: Retro.bevelLo
            border.color: Retro.bevelHi
            border.width: 1
        }
    }

    // Title strip
    Rectangle {
        id: titleStrip
        visible: root.title.length > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        height: root.titleH
        color: Retro.panelHi
        border.color: Retro.bevelLo
        border.width: 1
        radius: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            text: root.title
            color: root.titleColor
            font.family: Retro.mono
            font.bold: true
            font.pixelSize: Retro.fsHeader
        }

        Row {
            visible: root.showLeds
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 6
            spacing: 3
            Repeater {
                model: root.ledCount
                Rectangle {
                    width: 4; height: 4
                    radius: 1
                    color: index < root.activeLeds ? Retro.amber : Retro.amberDim
                    opacity: index < root.activeLeds ? 1.0 : 0.4
                }
            }
        }
    }

    // Scanline overlay (decorative)
    Item {
        anchors.fill: parent
        anchors.margins: 4
        z: 10
        visible: root.scanlineAlpha > 0
        Repeater {
            model: Math.floor(parent.height / 3)
            Rectangle {
                y: index * 3
                x: 0
                width: parent.width
                height: 1
                color: "#ffffff"
                opacity: root.scanlineAlpha
            }
        }
    }

    // Body — children of the panel live in here by default.
    Item {
        id: bodyContainer
        anchors.top: titleStrip.visible ? titleStrip.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        anchors.topMargin: titleStrip.visible ? 4 : 6
    }

    default property alias _content: bodyContainer.data
}
