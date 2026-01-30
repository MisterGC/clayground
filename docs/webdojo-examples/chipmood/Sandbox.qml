// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief SNES-style atmospheric music generator
// @tags Audio, Music, SNES, Chiptune, Synthesis

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Sound

/*!
    \qmltype Sandbox
    \brief ChipMood - SNES-style atmospheric music generator.

    Creates procedural atmospheric music inspired by classic SNES RPG soundtracks
    like Chrono Trigger, Secret of Mana, and Zelda: A Link to the Past.
*/
Rectangle {
    id: root
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Export state
    property bool exporting: false
    property real exportProgress: 0.0
    property bool exportCancelled: false

    // ChipMood music generator
    MoodPlayer {
        id: moodPlayer
        mood: "mysterious_forest"
        volume: volumeSlider.value
        intensity: intensitySlider.value
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: mainColumn.height
        clip: true

        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true

            Text {
                text: "ChipMood"
                font.family: root.monoFont
                font.pixelSize: 28
                font.bold: true
                color: root.accentColor
            }

            Text {
                text: "SNES-Style Music"
                font.family: root.monoFont
                font.pixelSize: 14
                color: root.dimTextColor
                Layout.leftMargin: 10
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 12; height: 12; radius: 6
                color: moodPlayer.playing ? "#4ade80" : root.dimTextColor

                SequentialAnimation on opacity {
                    running: moodPlayer.playing
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            Text {
                text: moodPlayer.playing ? "Playing" : (moodPlayer.ready ? "Ready" : "Loading...")
                font.family: root.monoFont
                font.pixelSize: 12
                color: moodPlayer.playing ? "#4ade80" : root.dimTextColor
                Layout.leftMargin: 5
            }
        }

        // Section Indicator
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: root.surfaceColor
            radius: 8
            visible: moodPlayer.playing

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 15

                Text {
                    text: "Section " + moodPlayer.sectionName
                    font.family: root.monoFont
                    font.pixelSize: 16
                    font.bold: true
                    color: root.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                    width: 90
                }

                Rectangle {
                    width: parent.width - 150
                    height: 8
                    radius: 4
                    color: Qt.darker(root.surfaceColor, 1.5)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: parent.width * moodPlayer.sectionProgress
                        height: parent.height
                        radius: 4
                        color: root.accentColor

                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }

                Text {
                    text: Math.round(moodPlayer.sectionProgress * 100) + "%"
                    font.family: root.monoFont
                    font.pixelSize: 12
                    color: root.dimTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                }
            }
        }

        // Mood Selection
        Rectangle {
            Layout.fillWidth: true
            height: moodGrid.height + 40
            color: root.surfaceColor
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                Text {
                    text: "Select Mood"
                    font.family: root.monoFont
                    font.pixelSize: 16
                    color: root.accentColor
                }

                Grid {
                    id: moodGrid
                    columns: 3
                    spacing: 10
                    width: parent.width

                    Repeater {
                        model: [
                            { id: "mysterious_forest", name: "Mysterious Forest", desc: "Dorian, ethereal, Secret of Mana" },
                            { id: "dark_dungeon", name: "Dark Dungeon", desc: "Phrygian, tense, Link to the Past" },
                            { id: "peaceful_village", name: "Peaceful Village", desc: "Major, light, Kakariko Village" }
                        ]

                        Rectangle {
                            width: (moodGrid.width - 20) / 3
                            height: 70
                            radius: 6
                            color: moodPlayer.mood === modelData.id ? root.accentColor : Qt.darker(root.surfaceColor, 1.3)
                            border.color: moodPlayer.mood === modelData.id ? Qt.lighter(root.accentColor, 1.3) : "transparent"
                            border.width: 2

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: modelData.name
                                    font.family: root.monoFont
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: root.textColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: modelData.desc
                                    font.family: root.monoFont
                                    font.pixelSize: 9
                                    color: root.dimTextColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.parent.width - 10
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const wasPlaying = moodPlayer.playing
                                    if (wasPlaying) moodPlayer.stop()
                                    moodPlayer.mood = modelData.id
                                    moodPlayer.play()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Controls
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: controlsCol.implicitHeight + 30
            color: root.surfaceColor
            radius: 8

            Column {
                id: controlsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 15
                spacing: 12

                Text {
                    text: "Controls"
                    font.family: root.monoFont
                    font.pixelSize: 16
                    color: root.accentColor
                }

                // Volume
                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Volume:"
                        font.family: root.monoFont
                        color: root.textColor
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: volumeSlider
                        width: parent.width - 140
                        from: 0; to: 1
                        value: 0.7
                    }

                    Text {
                        text: Math.round(volumeSlider.value * 100) + "%"
                        font.family: root.monoFont
                        color: root.dimTextColor
                        width: 40
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Intensity
                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Intensity:"
                        font.family: root.monoFont
                        color: root.textColor
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: intensitySlider
                        width: parent.width - 140
                        from: 0; to: 1
                        value: 0.5
                    }

                    Text {
                        text: intensitySlider.value < 0.3 ? "Sparse" :
                              intensitySlider.value < 0.6 ? "Normal" : "Full"
                        font.family: root.monoFont
                        color: root.dimTextColor
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Variation
                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Variation:"
                        font.family: root.monoFont
                        color: root.textColor
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: variationSlider
                        width: parent.width - 140
                        from: 0; to: 1
                        value: 0
                        onMoved: moodPlayer.variation = value
                    }

                    Text {
                        text: variationSlider.value < 0.3 ? "Stable" :
                              variationSlider.value < 0.6 ? "Some" : "Wild"
                        font.family: root.monoFont
                        color: root.dimTextColor
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Swing
                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Swing:"
                        font.family: root.monoFont
                        color: root.textColor
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: swingSlider
                        width: parent.width - 140
                        from: 0; to: 1
                        value: 0
                        onMoved: moodPlayer.swing = value
                    }

                    Text {
                        text: Math.round(swingSlider.value * 100) + "%"
                        font.family: root.monoFont
                        color: root.dimTextColor
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Octave
                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Octave:"
                        font.family: root.monoFont
                        color: root.textColor
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: octaveSlider
                        width: parent.width - 140
                        from: -2; to: 2
                        stepSize: 1
                        value: 0
                        onMoved: moodPlayer.octaveShift = value
                    }

                    Text {
                        text: octaveSlider.value > 0 ? "+" + octaveSlider.value : octaveSlider.value
                        font.family: root.monoFont
                        color: root.dimTextColor
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Playback
                Row {
                    width: parent.width
                    spacing: 10

                    Button {
                        text: moodPlayer.playing ? "Stop" : "Play"
                        enabled: moodPlayer.ready
                        onClicked: moodPlayer.playing ? moodPlayer.stop() : moodPlayer.play()

                        background: Rectangle {
                            color: moodPlayer.playing ? "#ef4444" : root.accentColor
                            radius: 4
                            implicitWidth: 60
                            implicitHeight: 30
                        }

                        contentItem: Text {
                            text: parent.text
                            font.family: root.monoFont
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "Shuffle"
                        enabled: moodPlayer.ready
                        onClicked: moodPlayer.randomize()

                        background: Rectangle {
                            color: Qt.darker(root.surfaceColor, 1.3)
                            radius: 4
                            implicitWidth: 60
                            implicitHeight: 30
                            border.color: root.accentColor
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font.family: root.monoFont
                            color: root.textColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        id: downloadBtn
                        text: "Download"
                        enabled: moodPlayer.ready && !root.exporting
                        onClicked: {
                            root.exporting = true
                            root.exportProgress = 0.0
                            root.exportCancelled = false
                            exportStartTimer.start()
                        }

                        Timer {
                            id: exportStartTimer
                            interval: 100
                            onTriggered: {
                                progressTimer.start()
                                moodPlayer.exportWav()
                            }
                        }

                        background: Rectangle {
                            color: "#2563eb"
                            radius: 4
                            implicitWidth: 90
                            implicitHeight: 30
                        }

                        contentItem: Text {
                            text: parent.text
                            font.family: root.monoFont
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Progress timer - estimate ~10 seconds for export
                    Timer {
                        id: progressTimer
                        interval: 100
                        repeat: true
                        onTriggered: {
                            if (root.exportCancelled) {
                                stop()
                                root.exporting = false
                                return
                            }
                            root.exportProgress = Math.min(0.95, root.exportProgress + 0.01)
                            if (root.exportProgress >= 0.95) {
                                // Wait for actual download, then reset
                                completeTimer.start()
                                stop()
                            }
                        }
                    }

                    Timer {
                        id: completeTimer
                        interval: 2000
                        onTriggered: {
                            root.exporting = false
                            root.exportProgress = 0
                        }
                    }

                    Text {
                        text: "Tempo: " + moodPlayer.tempo + " BPM"
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.dimTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Info
        Rectangle {
            Layout.fillWidth: true
            height: infoCol.height + 30
            color: root.surfaceColor
            radius: 8

            Column {
                id: infoCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "About ChipMood"
                    font.family: root.monoFont
                    font.pixelSize: 16
                    color: root.accentColor
                }

                Text {
                    text: "SNES-style atmospheric music using Web Audio synthesis.\n" +
                          "Oscillators + lowpass filter + echo/delay."
                    font.family: root.monoFont
                    font.pixelSize: 11
                    color: root.dimTextColor
                    wrapMode: Text.WordWrap
                    width: parent.width
                    lineHeight: 1.3
                }
            }
        }
    }  // ColumnLayout
    }  // Flickable

    // Export overlay
    Rectangle {
        anchors.fill: parent
        color: "#000000ee"
        visible: root.exporting
        z: 100

        MouseArea {
            anchors.fill: parent
            // Block clicks to content below
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "Generating WAV..."
                font.family: root.monoFont
                font.pixelSize: 24
                font.bold: true
                color: root.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Rendering " + (root.exportProgress * 100).toFixed(0) + "%"
                font.family: root.monoFont
                font.pixelSize: 14
                color: root.dimTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: 300
                height: 12
                radius: 6
                color: Qt.darker(root.surfaceColor, 1.5)
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: parent.width * root.exportProgress
                    height: parent.height
                    radius: 6
                    color: root.accentColor

                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }

            Button {
                text: "Cancel"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    root.exportCancelled = true
                }

                background: Rectangle {
                    color: "#ef4444"
                    radius: 4
                    implicitWidth: 80
                    implicitHeight: 30
                }

                contentItem: Text {
                    text: parent.text
                    font.family: root.monoFont
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                text: "This may take 10-20 seconds"
                font.family: root.monoFont
                font.pixelSize: 11
                color: root.dimTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
