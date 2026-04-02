// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief ChipMood - SNES-style atmospheric music generator with retro UI
// @tags Audio, Music, SNES, Chiptune, Synthesis, Retro

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Sound
import "Presets.js" as Presets

Rectangle {
    id: root
    color: "#0a0a12"

    // SNES-inspired color palette (16 colors)
    readonly property color snesBlack: "#0a0a12"
    readonly property color snesDarkBlue: "#1a1a2e"
    readonly property color snesMidBlue: "#16213e"
    readonly property color snesAccent: "#e6a020"      // Gold/orange
    readonly property color snesAccentDark: "#b87818"
    readonly property color snesHighlight: "#f0d060"
    readonly property color snesText: "#e8e8e8"
    readonly property color snesDimText: "#808090"
    readonly property color snesGreen: "#40c040"
    readonly property color snesRed: "#e04040"
    readonly property color snesCyan: "#40c0c0"
    readonly property color snesPurple: "#a060c0"

    // Pixel font (fallback to monospace)
    readonly property string pixelFont: "monospace"
    readonly property int pixelSize: 12

    // Export state
    property bool exporting: false
    property real exportProgress: 0.0

    // ChipMood music generator — presets loaded from Presets.js
    property string currentEnv: "forest"
    onCurrentEnvChanged: {
        let p = Presets.environments[currentEnv]
        if (p) {
            moodPlayer.preset = p
            moodPlayer.presetName = currentEnv
            moodPlayer.scale = p.defaultScale || "dorian"
        }
    }

    ChipMood {
        id: moodPlayer
        preset: Presets.environments["forest"]
        presetName: "forest"
        scale: "dorian"
        layers: ["arp", "melody", "pad", "bass"]
        seed: Math.floor(Math.random() * 10000)
        volume: volumeSlider.value
        intensity: intensitySlider.value
        variation: variationSlider.value
        swing: swingSlider.value
        brightness: brightnessSlider.value
        octaveShift: octaveSlider.value
    }

    // Scanline overlay effect
    Canvas {
        anchors.fill: parent
        z: 1000
        opacity: 0.08
        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = "#000000"
            ctx.lineWidth = 1
            for (var y = 0; y < height; y += 3) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentHeight: mainColumn.height + 20
        clip: true

        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 12

            // ══════════════════════════════════════════════════════════════
            // HEADER
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: root.snesDarkBlue
                border.color: root.snesAccent
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Text {
                        text: "♪ CHIPMOOD ♫"
                        font.family: root.pixelFont
                        font.pixelSize: 22
                        font.bold: true
                        color: root.snesAccent
                        style: Text.Outline
                        styleColor: root.snesAccentDark
                    }

                    Text {
                        text: "SNES MUSIC GENERATOR"
                        font.family: root.pixelFont
                        font.pixelSize: 10
                        color: root.snesDimText
                        Layout.alignment: Qt.AlignBottom
                    }

                    Item { Layout.fillWidth: true }

                    // Status indicator
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 2
                        color: moodPlayer.playing ? root.snesGreen : root.snesDimText
                        border.color: Qt.darker(color, 1.3)
                        border.width: 1

                        SequentialAnimation on opacity {
                            running: moodPlayer.playing
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 400 }
                            NumberAnimation { to: 1.0; duration: 400 }
                        }
                    }

                    Text {
                        text: moodPlayer.playing ? "PLAYING" : (moodPlayer.ready ? "READY" : "INIT...")
                        font.family: root.pixelFont
                        font.pixelSize: 10
                        font.bold: true
                        color: moodPlayer.playing ? root.snesGreen : root.snesDimText
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // SECTION PROGRESS
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2
                visible: moodPlayer.playing

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Text {
                        text: "SECTION"
                        font.family: root.pixelFont
                        font.pixelSize: 10
                        color: root.snesDimText
                    }

                    Rectangle {
                        width: 30
                        height: 24
                        color: root.snesAccent
                        radius: 2

                        Text {
                            anchors.centerIn: parent
                            text: moodPlayer.sectionName
                            font.family: root.pixelFont
                            font.pixelSize: 14
                            font.bold: true
                            color: root.snesBlack
                        }
                    }

                    // Progress bar using block characters
                    Rectangle {
                        Layout.fillWidth: true
                        height: 16
                        color: root.snesBlack
                        border.color: root.snesMidBlue
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 2

                            Repeater {
                                model: 20

                                Rectangle {
                                    width: (parent.width - 2) / 20
                                    height: parent.height
                                    color: index < Math.floor(moodPlayer.sectionProgress * 20)
                                           ? root.snesAccent : root.snesDarkBlue
                                }
                            }
                        }
                    }

                    Text {
                        text: Math.round(moodPlayer.sectionProgress * 100) + "%"
                        font.family: root.pixelFont
                        font.pixelSize: 10
                        color: root.snesDimText
                        Layout.preferredWidth: 35
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // ENVIRONMENT SELECTION
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: envContent.implicitHeight + 24
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                ColumnLayout {
                    id: envContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "▶ ENVIRONMENT"
                        font.family: root.pixelFont
                        font.pixelSize: 12
                        font.bold: true
                        color: root.snesAccent
                    }

                    GridLayout {
                        columns: 4
                        rowSpacing: 8
                        columnSpacing: 8
                        Layout.fillWidth: true

                        Repeater {
                            model: Presets.names

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 55
                                color: root.currentEnv === modelData
                                       ? root.snesAccent : root.snesMidBlue
                                border.color: root.currentEnv === modelData
                                              ? root.snesHighlight : root.snesDarkBlue
                                border.width: 2
                                radius: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: Presets.icons[modelData] || "?"
                                        font.pixelSize: 18
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: modelData.toUpperCase()
                                        font.family: root.pixelFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: root.currentEnv === modelData
                                               ? root.snesBlack : root.snesText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentEnv = modelData
                                        if (!moodPlayer.playing && moodPlayer.ready)
                                            moodPlayer.play()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: Presets.descriptions[root.currentEnv] || ""
                        font.family: root.pixelFont
                        font.pixelSize: 10
                        color: root.snesDimText
                        font.italic: true
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // SCALE SELECTION
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: scaleContent.implicitHeight + 24
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                ColumnLayout {
                    id: scaleContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "▶ SCALE"
                        font.family: root.pixelFont
                        font.pixelSize: 12
                        font.bold: true
                        color: root.snesAccent
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: moodPlayer.availableScales

                            Rectangle {
                                width: 85
                                height: 28
                                color: moodPlayer.scale === modelData
                                       ? root.snesCyan : root.snesMidBlue
                                border.color: moodPlayer.scale === modelData
                                              ? Qt.lighter(root.snesCyan, 1.3) : root.snesDarkBlue
                                border.width: 2
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: root.pixelFont
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: moodPlayer.scale === modelData
                                           ? root.snesBlack : root.snesText
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

            // ══════════════════════════════════════════════════════════════
            // LAYER TOGGLES
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: layerContent.implicitHeight + 24
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                ColumnLayout {
                    id: layerContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "▶ LAYERS"
                        font.family: root.pixelFont
                        font.pixelSize: 12
                        font.bold: true
                        color: root.snesAccent
                    }

                    Row {
                        spacing: 10

                        Repeater {
                            model: [
                                { id: "arp", name: "ARP", desc: "Arpeggios" },
                                { id: "melody", name: "MEL", desc: "Melody" },
                                { id: "pad", name: "PAD", desc: "Atmosphere" },
                                { id: "bass", name: "BASS", desc: "Bass" }
                            ]

                            Rectangle {
                                width: 70
                                height: 45
                                property bool active: moodPlayer.layers.indexOf(modelData.id) >= 0
                                color: active ? root.snesPurple : root.snesMidBlue
                                border.color: active ? Qt.lighter(root.snesPurple, 1.3) : root.snesDarkBlue
                                border.width: 2
                                radius: 2

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: parent.parent.active ? "■" : "□"
                                        font.family: root.pixelFont
                                        font.pixelSize: 14
                                        color: root.snesText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: root.pixelFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: parent.parent.active ? root.snesText : root.snesDimText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var layers = moodPlayer.layers.slice()
                                        var idx = layers.indexOf(modelData.id)
                                        if (idx >= 0) {
                                            if (layers.length > 1) // Keep at least one layer
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

            // ══════════════════════════════════════════════════════════════
            // CONTROLS
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: controlsContent.implicitHeight + 24
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                ColumnLayout {
                    id: controlsContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "▶ CONTROLS"
                        font.family: root.pixelFont
                        font.pixelSize: 12
                        font.bold: true
                        color: root.snesAccent
                    }

                    // Volume
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "VOLUME"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesText
                            Layout.preferredWidth: 70
                        }

                        RetroSlider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            value: 0.7
                        }

                        Text {
                            text: Math.round(volumeSlider.value * 100) + "%"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesDimText
                            Layout.preferredWidth: 40
                        }
                    }

                    // Intensity
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "INTENSITY"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesText
                            Layout.preferredWidth: 70
                        }

                        RetroSlider {
                            id: intensitySlider
                            Layout.fillWidth: true
                            value: 0.5
                        }

                        Text {
                            text: intensitySlider.value < 0.3 ? "SPARSE" :
                                  intensitySlider.value < 0.6 ? "NORMAL" : "FULL"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesDimText
                            Layout.preferredWidth: 50
                        }
                    }

                    // Brightness
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "BRIGHT"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesText
                            Layout.preferredWidth: 70
                        }

                        RetroSlider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            value: 0.5
                            barColor: root.snesHighlight
                        }

                        Text {
                            text: brightnessSlider.value < 0.3 ? "WARM" :
                                  brightnessSlider.value < 0.7 ? "NORMAL" : "CRISP"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesDimText
                            Layout.preferredWidth: 50
                        }
                    }

                    // Variation
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "VARIATION"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesText
                            Layout.preferredWidth: 70
                        }

                        RetroSlider {
                            id: variationSlider
                            Layout.fillWidth: true
                            value: 0.0
                            barColor: root.snesPurple
                        }

                        Text {
                            text: variationSlider.value < 0.3 ? "STABLE" :
                                  variationSlider.value < 0.6 ? "SOME" : "WILD"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesDimText
                            Layout.preferredWidth: 50
                        }
                    }

                    // Swing
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "SWING"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesText
                            Layout.preferredWidth: 70
                        }

                        RetroSlider {
                            id: swingSlider
                            Layout.fillWidth: true
                            value: 0.0
                            barColor: root.snesCyan
                        }

                        Text {
                            text: Math.round(swingSlider.value * 100) + "%"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesDimText
                            Layout.preferredWidth: 40
                        }
                    }

                    // Octave
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "OCTAVE"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesText
                            Layout.preferredWidth: 70
                        }

                        Row {
                            spacing: 4

                            Repeater {
                                model: [-2, -1, 0, 1, 2]

                                Rectangle {
                                    width: 36
                                    height: 24
                                    color: octaveSlider.value === modelData
                                           ? root.snesGreen : root.snesMidBlue
                                    border.color: octaveSlider.value === modelData
                                                  ? Qt.lighter(root.snesGreen, 1.3) : root.snesDarkBlue
                                    border.width: 2
                                    radius: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData > 0 ? "+" + modelData : modelData
                                        font.family: root.pixelFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: octaveSlider.value === modelData
                                               ? root.snesBlack : root.snesText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: octaveSlider.value = modelData
                                    }
                                }
                            }
                        }

                        // Hidden slider for binding
                        Slider {
                            id: octaveSlider
                            visible: false
                            from: -2
                            to: 2
                            stepSize: 1
                            value: 0
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "TEMPO: " + moodPlayer.tempo + " BPM"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            color: root.snesDimText
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // PLAYBACK BUTTONS
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Play/Stop button
                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 36
                        color: moodPlayer.playing ? root.snesRed : root.snesGreen
                        border.color: Qt.lighter(color, 1.3)
                        border.width: 2
                        radius: 2
                        opacity: moodPlayer.ready ? 1.0 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: moodPlayer.playing ? "■ STOP" : "▶ PLAY"
                            font.family: root.pixelFont
                            font.pixelSize: 12
                            font.bold: true
                            color: root.snesBlack
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: moodPlayer.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: moodPlayer.playing ? moodPlayer.stop() : moodPlayer.play()
                        }
                    }

                    // Shuffle button
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 36
                        color: root.snesMidBlue
                        border.color: root.snesAccent
                        border.width: 2
                        radius: 2
                        opacity: moodPlayer.ready ? 1.0 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "🎲 SHUFFLE"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            font.bold: true
                            color: root.snesText
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: moodPlayer.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: moodPlayer.randomize()
                        }
                    }

                    // New Seed button
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 36
                        color: root.snesMidBlue
                        border.color: root.snesCyan
                        border.width: 2
                        radius: 2

                        Text {
                            anchors.centerIn: parent
                            text: "🌱 SEED"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            font.bold: true
                            color: root.snesText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: moodPlayer.seed = Math.floor(Math.random() * 10000)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Download button
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 36
                        color: "#2563eb"
                        border.color: Qt.lighter(color, 1.3)
                        border.width: 2
                        radius: 2
                        opacity: moodPlayer.ready && !root.exporting ? 1.0 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "💾 DOWNLOAD"
                            font.family: root.pixelFont
                            font.pixelSize: 10
                            font.bold: true
                            color: root.snesText
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: moodPlayer.ready && !root.exporting
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.exporting = true
                                root.exportProgress = 0.0
                                exportTimer.start()
                                moodPlayer.exportWav()
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // SHARE CODE
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "▶ SHARE CODE"
                        font.family: root.pixelFont
                        font.pixelSize: 10
                        font.bold: true
                        color: root.snesAccent
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: root.snesBlack
                            border.color: root.snesMidBlue
                            border.width: 1
                            radius: 2

                            TextInput {
                                id: shareCodeInput
                                anchors.fill: parent
                                anchors.margins: 6
                                text: moodPlayer.shareCode
                                font.family: root.pixelFont
                                font.pixelSize: 11
                                color: root.snesHighlight
                                selectByMouse: true
                                clip: true

                                onAccepted: moodPlayer.shareCode = text
                            }
                        }

                        Rectangle {
                            width: 60
                            height: 28
                            color: root.snesMidBlue
                            border.color: root.snesAccent
                            border.width: 2
                            radius: 2

                            Text {
                                anchors.centerIn: parent
                                text: "APPLY"
                                font.family: root.pixelFont
                                font.pixelSize: 9
                                font.bold: true
                                color: root.snesText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: moodPlayer.shareCode = shareCodeInput.text
                            }
                        }

                        Rectangle {
                            width: 50
                            height: 28
                            color: root.snesMidBlue
                            border.color: root.snesCyan
                            border.width: 2
                            radius: 2

                            Text {
                                anchors.centerIn: parent
                                text: "COPY"
                                font.family: root.pixelFont
                                font.pixelSize: 9
                                font.bold: true
                                color: root.snesText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    shareCodeInput.selectAll()
                                    shareCodeInput.copy()
                                    shareCodeInput.deselect()
                                }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // INFO
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: root.snesDarkBlue
                border.color: root.snesMidBlue
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "SEED: " + moodPlayer.seed + " | " +
                          root.currentEnv.toUpperCase() + " + " +
                          moodPlayer.scale.toUpperCase()
                    font.family: root.pixelFont
                    font.pixelSize: 10
                    color: root.snesDimText
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // EXPORT OVERLAY
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        color: "#000000ee"
        visible: root.exporting
        z: 500

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

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "GENERATING WAV..."
                font.family: root.pixelFont
                font.pixelSize: 20
                font.bold: true
                color: root.snesAccent
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Pixelated progress bar
            Rectangle {
                width: 300
                height: 24
                color: root.snesBlack
                border.color: root.snesAccent
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    anchors.fill: parent
                    anchors.margins: 4

                    Repeater {
                        model: 20

                        Rectangle {
                            width: (parent.width) / 20 - 1
                            height: parent.height
                            color: index < Math.floor(root.exportProgress * 20)
                                   ? root.snesAccent : root.snesDarkBlue
                        }
                    }
                }
            }

            Text {
                text: Math.round(root.exportProgress * 100) + "%"
                font.family: root.pixelFont
                font.pixelSize: 14
                color: root.snesDimText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // RETRO SLIDER COMPONENT
    // ══════════════════════════════════════════════════════════════
    component RetroSlider: Item {
        id: sliderRoot
        height: 20

        property real value: 0.5
        property real from: 0.0
        property real to: 1.0
        property color barColor: root.snesAccent

        Rectangle {
            anchors.fill: parent
            color: root.snesBlack
            border.color: root.snesMidBlue
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 2

                Repeater {
                    model: 20

                    Rectangle {
                        width: (parent.width) / 20
                        height: parent.height
                        color: {
                            var normalizedValue = (sliderRoot.value - sliderRoot.from) /
                                                  (sliderRoot.to - sliderRoot.from)
                            return index < Math.floor(normalizedValue * 20)
                                   ? sliderRoot.barColor : root.snesDarkBlue
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    var ratio = mouse.x / width
                    sliderRoot.value = sliderRoot.from + ratio * (sliderRoot.to - sliderRoot.from)
                }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var ratio = Math.max(0, Math.min(1, mouse.x / width))
                        sliderRoot.value = sliderRoot.from + ratio * (sliderRoot.to - sliderRoot.from)
                    }
                }
            }
        }
    }
}
