// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Welcome landing screen
// @tags Welcome

import QtQuick

Rectangle {
    id: root
    color: "#0d1117"

    // Floating particles
    Repeater {
        model: 18
        Rectangle {
            id: particle
            property real seed: index * 137.508
            width: 3 + Math.random() * 4
            height: width
            radius: width / 2
            color: "#00d9ff"
            opacity: 0.08 + Math.random() * 0.15
            x: (seed * 7.3) % root.width
            y: (seed * 13.1) % root.height

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation {
                    to: particle.y - 30 - Math.random() * 40
                    duration: 3000 + particle.seed % 2000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.y
                    duration: 3000 + particle.seed % 2000
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.04
                    duration: 2500 + particle.seed % 1500
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 0.08 + Math.random() * 0.15
                    duration: 2500 + particle.seed % 1500
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: parent.height * 0.03
        width: parent.width * 0.85

        // Title
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Clayground"
            color: "#00d9ff"
            font.pixelSize: root.height * 0.09
            font.bold: true

            SequentialAnimation on opacity {
                running: true
                NumberAnimation { from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
            }
        }

        // Tagline
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Rapid Prototyping with Live Reloading"
            color: "#8b949e"
            font.pixelSize: root.height * 0.035
            horizontalAlignment: Text.AlignHCenter

            SequentialAnimation on opacity {
                running: true
                PauseAnimation { duration: 300 }
                NumberAnimation { from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
            }
        }

        // Separator
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width * 0.15
            height: 1
            color: "#00d9ff"
            opacity: 0.3

            SequentialAnimation on opacity {
                running: true
                PauseAnimation { duration: 500 }
                NumberAnimation { from: 0; to: 0.3; duration: 600; easing.type: Easing.OutCubic }
            }
        }

        // Sidebar options
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.height * 0.018
            topPadding: root.height * 0.01

            Repeater {
                model: [
                    { icon: "\u25A6", label: "Examples \u2014 browse interactive demos" },
                    { icon: "+", label: "New Script \u2014 create & share your own QML" },
                    { icon: "\u25CB", label: "URL \u2014 load a project from any URL" },
                    { icon: "\u25A3", label: "Dev Server \u2014 develop locally with live-reload" }
                ]

                Text {
                    required property var modelData
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "<font color='#00d9ff'>" + modelData.icon +
                          "</font>&nbsp;&nbsp;" + modelData.label
                    textFormat: Text.RichText
                    color: "#c9d1d9"
                    font.pixelSize: root.height * 0.03

                    SequentialAnimation on opacity {
                        running: true
                        PauseAnimation { duration: 700 + index * 200 }
                        NumberAnimation { from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // Accent glow behind title
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.06
        width: root.width * 0.5
        height: root.height * 0.25
        radius: height / 2
        color: "#00d9ff"
        opacity: 0.03

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.05; duration: 3000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.03; duration: 3000; easing.type: Easing.InOutSine }
        }
    }
}
