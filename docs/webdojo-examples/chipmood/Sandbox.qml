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

    Features 8 environments, 8 scales, layer control, and shareable codes.
*/
Rectangle {
    id: root
    color: "#1a1a2e"

    property color accentColor: "#e6a020"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    property bool exporting: false
    property real exportProgress: 0.0

    readonly property var envIcons: ({
        "forest": "🌲", "dungeon": "💀", "village": "🏠", "cave": "🦇",
        "mountain": "🏔", "ocean": "🌊", "desert": "🏜", "snow": "❄"
    })

    MoodPlayer {
        id: moodPlayer
        environment: "forest"
        scale: "dorian"
        layers: ["arp", "melody", "pad", "bass"]
        seed: Math.floor(Math.random() * 10000)
        volume: volumeSlider.value
        intensity: intensitySlider.value
        variation: variationSlider.value
        swing: swingSlider.value
        brightness: brightnessSlider.value
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

            // Environment Selection
            Rectangle {
                Layout.fillWidth: true
                height: envGrid.height + 50
                color: root.surfaceColor
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 12

                    Text {
                        text: "Environment"
                        font.family: root.monoFont
                        font.pixelSize: 16
                        color: root.accentColor
                    }

                    Grid {
                        id: envGrid
                        columns: 4
                        spacing: 8
                        width: parent.width

                        Repeater {
                            model: moodPlayer.availableEnvironments

                            Rectangle {
                                width: (envGrid.width - 24) / 4
                                height: 55
                                radius: 6
                                color: moodPlayer.environment === modelData
                                       ? root.accentColor : Qt.darker(root.surfaceColor, 1.3)
                                border.color: moodPlayer.environment === modelData
                                              ? Qt.lighter(root.accentColor, 1.3) : "transparent"
                                border.width: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: root.envIcons[modelData] || "?"
                                        font.pixelSize: 16
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: modelData
                                        font.family: root.monoFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: moodPlayer.environment === modelData
                                               ? "#1a1a2e" : root.textColor
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Reset controls to defaults before environment change
                                        intensitySlider.value = 0.5
                                        variationSlider.value = 0.0
                                        swingSlider.value = 0.0
                                        brightnessSlider.value = 0.5
                                        moodPlayer.octaveShift = 0

                                        moodPlayer.environment = modelData
                                        if (!moodPlayer.playing && moodPlayer.ready)
                                            moodPlayer.play()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Scale Selection
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: scaleCol.implicitHeight + 30
                color: root.surfaceColor
                radius: 8

                Column {
                    id: scaleCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 15
                    spacing: 12

                    Text {
                        text: "Scale"
                        font.family: root.monoFont
                        font.pixelSize: 16
                        color: root.accentColor
                    }

                    Flow {
                        id: scaleFlow
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: moodPlayer.availableScales

                            Rectangle {
                                width: 80
                                height: 28
                                radius: 4
                                color: moodPlayer.scale === modelData
                                       ? "#40c0c0" : Qt.darker(root.surfaceColor, 1.3)
                                border.color: moodPlayer.scale === modelData
                                              ? Qt.lighter("#40c0c0", 1.3) : "transparent"
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: root.monoFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: moodPlayer.scale === modelData
                                           ? "#1a1a2e" : root.textColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: moodPlayer.scale = modelData
                                }
                            }
                        }
                    }
                }
            }

            // Layer Toggles
            Rectangle {
                Layout.fillWidth: true
                height: 80
                color: root.surfaceColor
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 12

                    Text {
                        text: "Layers"
                        font.family: root.monoFont
                        font.pixelSize: 16
                        color: root.accentColor
                    }

                    Row {
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "arp", name: "Arp" },
                                { id: "melody", name: "Melody" },
                                { id: "pad", name: "Pad" },
                                { id: "bass", name: "Bass" }
                            ]

                            Rectangle {
                                width: 65
                                height: 30
                                radius: 4
                                property bool active: moodPlayer.layers.indexOf(modelData.id) >= 0
                                color: active ? "#a060c0" : Qt.darker(root.surfaceColor, 1.3)
                                border.color: active ? Qt.lighter("#a060c0", 1.3) : "transparent"
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: (parent.active ? "■ " : "□ ") + modelData.name
                                    font.family: root.monoFont
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: parent.active ? root.textColor : root.dimTextColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var layers = moodPlayer.layers.slice()
                                        var idx = layers.indexOf(modelData.id)
                                        if (idx >= 0) {
                                            if (layers.length > 1)
                                                layers.splice(idx, 1)
                                        } else {
                                            layers.push(modelData.id)
                                        }
                                        moodPlayer.layers = layers
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
                    spacing: 10

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
                            width: parent.width - 130
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
                            width: parent.width - 130
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

                    // Brightness
                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: "Bright:"
                            font.family: root.monoFont
                            color: root.textColor
                            width: 70
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Slider {
                            id: brightnessSlider
                            width: parent.width - 130
                            from: 0; to: 1
                            value: 0.5
                        }

                        Text {
                            text: brightnessSlider.value < 0.3 ? "Warm" :
                                  brightnessSlider.value < 0.7 ? "Normal" : "Crisp"
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
                            width: parent.width - 130
                            from: 0; to: 1
                            value: 0
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
                            width: parent.width - 130
                            from: 0; to: 1
                            value: 0
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

                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [-2, -1, 0, 1, 2]

                                Rectangle {
                                    width: 40
                                    height: 30
                                    radius: 4
                                    property bool active: moodPlayer.octaveShift === modelData
                                    color: active ? "#a060c0" : Qt.darker(root.surfaceColor, 1.3)
                                    border.color: active ? Qt.lighter("#a060c0", 1.3) : "transparent"
                                    border.width: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData > 0 ? "+" + modelData : modelData
                                        font.family: root.monoFont
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: parent.active ? root.textColor : root.dimTextColor
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: moodPlayer.octaveShift = modelData
                                    }
                                }
                            }
                        }
                    }

                    // Tempo (BPM)
                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: "Tempo:"
                            font.family: root.monoFont
                            color: root.textColor
                            width: 70
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Slider {
                            id: tempoSlider
                            width: parent.width - 130
                            from: 60; to: 180
                            stepSize: 1
                            value: moodPlayer.tempo
                            onMoved: moodPlayer.tempo = value
                        }

                        Text {
                            text: tempoSlider.value + " BPM"
                            font.family: root.monoFont
                            color: root.dimTextColor
                            width: 60
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
                                color: moodPlayer.playing ? "#ef4444" : "#4ade80"
                                radius: 4
                                implicitWidth: 60
                                implicitHeight: 30
                            }

                            contentItem: Text {
                                text: parent.text
                                font.family: root.monoFont
                                color: "#1a1a2e"
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
                            text: "New Seed"
                            enabled: moodPlayer.ready
                            onClicked: moodPlayer.seed = Math.floor(Math.random() * 10000)

                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 4
                                implicitWidth: 70
                                implicitHeight: 30
                                border.color: "#40c0c0"
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
                            text: "Download"
                            enabled: moodPlayer.ready && !root.exporting
                            onClicked: {
                                root.exporting = true
                                root.exportProgress = 0.0
                                exportTimer.start()
                                moodPlayer.exportWav()
                            }

                            Timer {
                                id: exportTimer
                                interval: 150
                                repeat: true
                                onTriggered: {
                                    root.exportProgress = Math.min(0.95, root.exportProgress + 0.02)
                                    if (root.exportProgress >= 0.95) {
                                        stop()
                                        completeTimer.start()
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

                            background: Rectangle {
                                color: "#2563eb"
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
                    }
                }
            }

            // Share Code
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: root.surfaceColor
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    Text {
                        text: "Share Code"
                        font.family: root.monoFont
                        font.pixelSize: 14
                        color: root.accentColor
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - 120
                            height: 28
                            color: "#0a0a12"
                            radius: 4
                            border.color: Qt.darker(root.surfaceColor, 1.3)
                            border.width: 1

                            TextInput {
                                id: shareCodeInput
                                anchors.fill: parent
                                anchors.margins: 6
                                text: moodPlayer.shareCode
                                font.family: root.monoFont
                                font.pixelSize: 11
                                color: "#f0d060"
                                selectByMouse: true
                                clip: true

                                onAccepted: moodPlayer.shareCode = text
                            }
                        }

                        Button {
                            text: "Apply"
                            width: 50
                            height: 28
                            onClicked: moodPlayer.shareCode = shareCodeInput.text

                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 4
                                border.color: root.accentColor
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                font.family: root.monoFont
                                font.pixelSize: 10
                                color: root.textColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Button {
                            text: "Copy"
                            width: 50
                            height: 28
                            onClicked: {
                                shareCodeInput.selectAll()
                                shareCodeInput.copy()
                                shareCodeInput.deselect()
                            }

                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 4
                                border.color: "#40c0c0"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                font.family: root.monoFont
                                font.pixelSize: 10
                                color: root.textColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // Info
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: root.surfaceColor
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: "Seed: " + moodPlayer.seed + " | " +
                          moodPlayer.environment + " + " + moodPlayer.scale
                    font.family: root.monoFont
                    font.pixelSize: 11
                    color: root.dimTextColor
                }
            }
        }
    }

    // Export overlay
    Rectangle {
        anchors.fill: parent
        color: "#000000ee"
        visible: root.exporting
        z: 100

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

            Text {
                text: Math.round(root.exportProgress * 100) + "%"
                font.family: root.monoFont
                font.pixelSize: 14
                color: root.dimTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
