// (c) Clayground Contributors - MIT License, see "LICENSE" file
// ChipTracker — SNES-style step sequencer with retro UI
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Sound
import "Presets.js" as Presets
import "Generator.js" as Generator
import "Instruments.js" as Inst
import "Phrases.js" as Phr

Rectangle {
    id: root
    color: snesBlack

    // SNES-inspired palette
    readonly property color snesBlack: "#0a0a12"
    readonly property color snesDarkBlue: "#1a1a2e"
    readonly property color snesMidBlue: "#16213e"
    readonly property color snesAccent: "#e6a020"
    readonly property color snesAccentDark: "#b87818"
    readonly property color snesHighlight: "#f0d060"
    readonly property color snesText: "#e8e8e8"
    readonly property color snesDimText: "#808090"
    readonly property color snesGreen: "#40c040"
    readonly property color snesRed: "#e04040"
    readonly property color snesCyan: "#40c0c0"
    readonly property color snesPurple: "#a060c0"

    readonly property string pixelFont: "monospace"
    readonly property int pixelSize: 12

    // Note colors per scale degree
    readonly property var noteColors: [
        "#e6a020", "#40c0c0", "#40c040", "#a060c0",
        "#2563eb", "#e07020", "#e04040", "#f0d060"
    ]

    readonly property var scaleLengths: ({
        major: 7, minor: 7, dorian: 7, phrygian: 7,
        lydian: 7, mixolydian: 7, pentatonic: 5, blues: 6
    })
    property int scaleLen: scaleLengths[tracker.scale] || 7

    property string currentEnv: "forest"
    property int selectedChannel: 0
    property int seed: Math.floor(Math.random() * 10000)
    property bool exporting: false
    property real exportProgress: 0.0

    // Track channel roles for phrase filtering
    property var channelRoles: ["arp", "melody", "pad", "bass"]

    ChipTracker {
        id: tracker
        steps: 16
        channelCount: 4
        scale: "dorian"
        rootNote: 48
        tempo: 85
        volume: volumeSlider.value
        swing: swingSlider.value
        brightness: brightnessSlider.value
        echoMix: echoSlider.value
    }

    function generateFromPreset(envName) {
        var preset = Presets.environments[envName]
        if (!preset) return
        var result = Generator.generate(preset, tracker.scale, root.seed, tracker.steps)
        tracker.scale = result.scale
        tracker.tempo = result.tempo
        tracker.rootNote = result.rootNote
        tracker.echoMix = result.echoMix
        tracker.brightness = result.brightness

        for (var ch = 0; ch < result.channels.length && ch < tracker.channelCount; ch++) {
            var chData = result.channels[ch]
            root.channelRoles[ch] = chData.role
            tracker.setChannelPatch(ch, Inst.patches[chData.patch])
            tracker.setChannelOctave(ch, chData.octave)
            tracker.setChannelPattern(ch, chData.pattern)
        }
        root.channelRolesChanged()

        if (!tracker.playing && tracker.ready) tracker.play()
    }

    Component.onCompleted: generateFromPreset("forest")

    // Scanline overlay
    Canvas {
        anchors.fill: parent; z: 1000; opacity: 0.06
        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = "#000000"; ctx.lineWidth = 1
            for (var y = 0; y < height; y += 3) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }

    Flickable {
        anchors.fill: parent; anchors.margins: 10
        contentHeight: mainCol.height + 20; clip: true

        ColumnLayout {
            id: mainCol
            width: parent.width; spacing: 8

            // ══════════════════════════════════════════════════════════
            // HEADER
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 44
                color: snesDarkBlue; border.color: snesAccent; border.width: 2

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                    Text {
                        text: "♪ CHIPTRACKER ♫"; font.family: pixelFont
                        font.pixelSize: 20; font.bold: true
                        color: snesAccent; style: Text.Outline; styleColor: snesAccentDark
                    }
                    Text {
                        text: "SNES STEP SEQUENCER"; font.family: pixelFont
                        font.pixelSize: 9; color: snesDimText
                        Layout.alignment: Qt.AlignBottom
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: tracker.tempo + " BPM"; font.family: pixelFont
                        font.pixelSize: 11; font.bold: true; color: snesCyan
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 2
                        color: tracker.playing ? snesGreen : snesDimText
                        SequentialAnimation on opacity {
                            running: tracker.playing; loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 400 }
                            NumberAnimation { to: 1.0; duration: 400 }
                        }
                    }
                    Text {
                        text: tracker.playing ? "PLAYING" : "READY"
                        font.family: pixelFont; font.pixelSize: 9; font.bold: true
                        color: tracker.playing ? snesGreen : snesDimText
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // GENERATE — Environment presets
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: genCol.implicitHeight + 20
                color: snesDarkBlue; border.color: snesMidBlue; border.width: 2

                ColumnLayout {
                    id: genCol; anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Text {
                        text: "▶ GENERATE"; font.family: pixelFont
                        font.pixelSize: 11; font.bold: true; color: snesAccent
                    }
                    GridLayout {
                        columns: 4; rowSpacing: 6; columnSpacing: 6
                        Layout.fillWidth: true
                        Repeater {
                            model: Presets.names
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 48
                                color: currentEnv === modelData ? snesAccent : snesMidBlue
                                border.color: currentEnv === modelData ? snesHighlight : snesDarkBlue
                                border.width: 2; radius: 2
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        text: Presets.icons[modelData] || "?"
                                        font.pixelSize: 16
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: modelData.toUpperCase()
                                        font.family: pixelFont; font.pixelSize: 8; font.bold: true
                                        color: currentEnv === modelData ? snesBlack : snesText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { currentEnv = modelData; generateFromPreset(modelData) }
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "SEED: " + root.seed; font.family: pixelFont
                            font.pixelSize: 9; color: snesDimText
                        }
                        Rectangle {
                            width: 55; height: 22; color: snesMidBlue
                            border.color: snesCyan; border.width: 1; radius: 2
                            Text {
                                anchors.centerIn: parent; text: "🎲 NEW"
                                font.family: pixelFont; font.pixelSize: 8; color: snesText
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.seed = Math.floor(Math.random() * 10000); generateFromPreset(currentEnv) }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // SCALE SELECTOR
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: scaleCol.implicitHeight + 20
                color: snesDarkBlue; border.color: snesMidBlue; border.width: 2

                ColumnLayout {
                    id: scaleCol; anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Text {
                        text: "▶ SCALE"; font.family: pixelFont
                        font.pixelSize: 11; font.bold: true; color: snesAccent
                    }
                    Flow {
                        Layout.fillWidth: true; spacing: 5
                        Repeater {
                            model: tracker.availableScales
                            Rectangle {
                                width: 78; height: 24
                                color: tracker.scale === modelData ? snesCyan : snesMidBlue
                                border.color: tracker.scale === modelData ? Qt.lighter(snesCyan, 1.3) : snesDarkBlue
                                border.width: 2; radius: 2
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: pixelFont; font.pixelSize: 8; font.bold: true
                                    color: tracker.scale === modelData ? snesBlack : snesText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: tracker.scale = modelData
                                }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // STEP GRID
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: gridCol.implicitHeight + 20
                color: snesDarkBlue; border.color: snesAccent; border.width: 2

                ColumnLayout {
                    id: gridCol; anchors.fill: parent; anchors.margins: 10; spacing: 6

                    Text {
                        text: "▶ PATTERN"; font.family: pixelFont
                        font.pixelSize: 11; font.bold: true; color: snesAccent
                    }

                    // Step numbers header
                    RowLayout {
                        spacing: 0
                        Item { Layout.preferredWidth: 70 }
                        Repeater {
                            model: tracker.steps
                            Text {
                                Layout.preferredWidth: (mainCol.width - 110) / tracker.steps
                                text: (index + 1).toString()
                                font.family: pixelFont; font.pixelSize: 7
                                color: (index % 4 === 0) ? snesDimText : Qt.darker(snesDimText, 1.5)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Grid rows (one per channel)
                    Repeater {
                        id: gridRows
                        model: tracker.channelCount

                        RowLayout {
                            id: chRow
                            required property int index
                            property int ch: index
                            spacing: 0

                            // Channel label
                            Rectangle {
                                Layout.preferredWidth: 70; Layout.preferredHeight: 26
                                color: selectedChannel === chRow.ch ? Qt.darker(snesAccent, 2.5) : "transparent"
                                radius: 2

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 4; spacing: 4
                                    // Mute indicator
                                    Rectangle {
                                        width: 8; height: 8; radius: 1
                                        color: {
                                            var info = tracker.channelInfo(chRow.ch)
                                            return info.muted ? snesRed : noteColors[chRow.ch % noteColors.length]
                                        }
                                    }
                                    Text {
                                        text: {
                                            var roles = root.channelRoles
                                            return (roles[chRow.ch] || ("CH" + (chRow.ch + 1))).toUpperCase()
                                        }
                                        font.family: pixelFont; font.pixelSize: 9; font.bold: true
                                        color: selectedChannel === chRow.ch ? snesAccent : snesText
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: selectedChannel = chRow.ch
                                }
                            }

                            // Step cells
                            Repeater {
                                model: tracker.steps
                                Rectangle {
                                    id: cellRect
                                    required property int index
                                    property int step: index
                                    property int ch: chRow.ch
                                    property var cellData: tracker.grid[ch * tracker.steps + step]
                                    property int note: cellData ? cellData.note : -1
                                    property bool isPlayback: tracker.playbackStep === step && tracker.playing

                                    Layout.preferredWidth: (mainCol.width - 110) / tracker.steps
                                    Layout.preferredHeight: 26
                                    radius: 1

                                    color: {
                                        if (note >= 0) {
                                            var c = noteColors[note % noteColors.length]
                                            return isPlayback ? Qt.lighter(c, 1.4) : c
                                        }
                                        if (isPlayback) return snesMidBlue
                                        return (step % 4 === 0) ? "#0d0d1a" : snesBlack
                                    }
                                    border.color: isPlayback ? snesHighlight : Qt.darker(snesMidBlue, 1.3)
                                    border.width: isPlayback ? 2 : 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: cellRect.note >= 0 ? cellRect.note.toString() : ""
                                        font.family: pixelFont; font.pixelSize: 9; font.bold: true
                                        color: cellRect.note >= 0 ? snesBlack : "transparent"
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.RightButton) {
                                                tracker.clearCell(cellRect.ch, cellRect.step)
                                                return
                                            }
                                            if (cellRect.note < 0)
                                                tracker.setCell(cellRect.ch, cellRect.step, 0)
                                            else if (cellRect.note >= scaleLen - 1)
                                                tracker.clearCell(cellRect.ch, cellRect.step)
                                            else
                                                tracker.setCell(cellRect.ch, cellRect.step, cellRect.note + 1)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Beat markers under grid
                    RowLayout {
                        spacing: 0
                        Item { Layout.preferredWidth: 70 }
                        Repeater {
                            model: tracker.steps
                            Rectangle {
                                Layout.preferredWidth: (mainCol.width - 110) / tracker.steps
                                height: 3
                                color: (index % 4 === 0) ? snesAccentDark : "transparent"
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // CHANNEL CONFIG (for selected channel)
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: chCfgCol.implicitHeight + 20
                color: snesDarkBlue; border.color: snesMidBlue; border.width: 2

                ColumnLayout {
                    id: chCfgCol; anchors.fill: parent; anchors.margins: 10; spacing: 8

                    Text {
                        text: "▶ CHANNEL " + (selectedChannel + 1) + " — " +
                              (channelRoles[selectedChannel] || "").toUpperCase()
                        font.family: pixelFont; font.pixelSize: 11; font.bold: true; color: snesAccent
                    }

                    // Patch selector
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "PATCH"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText
                            Layout.preferredWidth: 50
                        }
                        Flow {
                            Layout.fillWidth: true; spacing: 4
                            Repeater {
                                model: Inst.patchIds
                                Rectangle {
                                    property string pid: modelData
                                    property bool isCurrent: {
                                        var info = tracker.channelInfo(selectedChannel)
                                        return info.patchName === Inst.patches[pid].name
                                    }
                                    width: patchLabel.implicitWidth + 12; height: 22
                                    color: isCurrent ? noteColors[selectedChannel % noteColors.length] : snesMidBlue
                                    border.color: isCurrent ? snesHighlight : snesDarkBlue
                                    border.width: 1; radius: 2
                                    Text {
                                        id: patchLabel; anchors.centerIn: parent
                                        text: Inst.patches[pid].name
                                        font.family: pixelFont; font.pixelSize: 7; font.bold: isCurrent
                                        color: isCurrent ? snesBlack : snesText
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: tracker.setChannelPatch(selectedChannel, Inst.patches[pid])
                                    }
                                }
                            }
                        }
                    }

                    // Octave + Mute
                    RowLayout {
                        spacing: 10
                        Text {
                            text: "OCTAVE"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText
                        }
                        Repeater {
                            model: [-2, -1, 0, 1, 2]
                            Rectangle {
                                required property var modelData
                                property bool isCurrent: tracker.channelInfo(selectedChannel).octave === modelData
                                width: 28; height: 22
                                color: isCurrent ? snesCyan : snesMidBlue
                                border.color: isCurrent ? Qt.lighter(snesCyan, 1.3) : snesDarkBlue
                                border.width: 1; radius: 2
                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData >= 0 ? "+" : "") + modelData
                                    font.family: pixelFont; font.pixelSize: 8; font.bold: true
                                    color: isCurrent ? snesBlack : snesText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: tracker.setChannelOctave(selectedChannel, modelData)
                                }
                            }
                        }
                        Item { Layout.preferredWidth: 15 }
                        Rectangle {
                            property bool muted: tracker.channelInfo(selectedChannel).muted || false
                            width: 45; height: 22
                            color: muted ? snesRed : snesMidBlue
                            border.color: muted ? Qt.lighter(snesRed, 1.3) : snesDarkBlue
                            border.width: 1; radius: 2
                            Text {
                                anchors.centerIn: parent; text: "MUTE"
                                font.family: pixelFont; font.pixelSize: 8; font.bold: true
                                color: parent.muted ? snesBlack : snesText
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: tracker.setChannelMuted(selectedChannel, !parent.muted)
                            }
                        }
                        Rectangle {
                            width: 50; height: 22; color: snesMidBlue
                            border.color: snesRed; border.width: 1; radius: 2
                            Text {
                                anchors.centerIn: parent; text: "CLEAR"
                                font.family: pixelFont; font.pixelSize: 8; font.bold: true; color: snesText
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: tracker.clearChannel(selectedChannel)
                            }
                        }
                    }

                    // Phrase presets
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "PHRASE"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText
                            Layout.preferredWidth: 50
                        }
                        Flow {
                            Layout.fillWidth: true; spacing: 4
                            Repeater {
                                model: {
                                    var role = channelRoles[selectedChannel] || ""
                                    return Phr.byRole(role)
                                }
                                Rectangle {
                                    property string phraseId: modelData
                                    width: phraseLabel.implicitWidth + 12; height: 22
                                    color: snesMidBlue
                                    border.color: snesPurple; border.width: 1; radius: 2
                                    Text {
                                        id: phraseLabel; anchors.centerIn: parent
                                        text: Phr.phrases[phraseId].name
                                        font.family: pixelFont; font.pixelSize: 7; color: snesText
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var phrase = Phr.phrases[phraseId]
                                            var tiled = Generator.tile(phrase.steps, tracker.steps)
                                            tracker.setChannelPattern(selectedChannel, tiled)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // SLIDERS
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sliderGrid.implicitHeight + 20
                color: snesDarkBlue; border.color: snesMidBlue; border.width: 2

                GridLayout {
                    id: sliderGrid; anchors.fill: parent; anchors.margins: 10
                    columns: 4; rowSpacing: 6; columnSpacing: 10

                    Text { text: "VOLUME"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText }
                    RetroSlider {
                        id: volumeSlider; Layout.fillWidth: true; value: 0.7
                    }
                    Text { text: "BRIGHTNESS"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText }
                    RetroSlider {
                        id: brightnessSlider; Layout.fillWidth: true; value: 0.5; barColor: snesCyan
                    }
                    Text { text: "ECHO"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText }
                    RetroSlider {
                        id: echoSlider; Layout.fillWidth: true; value: 0.3; barColor: snesPurple
                    }
                    Text { text: "SWING"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText }
                    RetroSlider {
                        id: swingSlider; Layout.fillWidth: true; value: 0.0; barColor: snesGreen
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // PLAYBACK CONTROLS
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 50
                color: snesDarkBlue; border.color: snesMidBlue; border.width: 2

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    // Play/Stop
                    Rectangle {
                        Layout.preferredWidth: 80; Layout.preferredHeight: 34
                        color: tracker.playing ? snesRed : snesGreen
                        border.color: Qt.lighter(color, 1.3); border.width: 2; radius: 2
                        Text {
                            anchors.centerIn: parent
                            text: tracker.playing ? "■ STOP" : "▶ PLAY"
                            font.family: pixelFont; font.pixelSize: 10; font.bold: true
                            color: snesBlack
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: tracker.playing ? tracker.stop() : tracker.play()
                        }
                    }

                    // Clear All
                    Rectangle {
                        Layout.preferredWidth: 75; Layout.preferredHeight: 34
                        color: snesMidBlue; border.color: snesRed; border.width: 2; radius: 2
                        Text {
                            anchors.centerIn: parent; text: "× CLEAR"
                            font.family: pixelFont; font.pixelSize: 10; font.bold: true; color: snesText
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: tracker.clearAll()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Tempo buttons
                    Text {
                        text: "TEMPO"; font.family: pixelFont; font.pixelSize: 9; color: snesDimText
                    }
                    Rectangle {
                        width: 28; height: 28; color: snesMidBlue; radius: 2
                        border.color: snesDarkBlue; border.width: 1
                        Text { anchors.centerIn: parent; text: "-"; font.pixelSize: 14; color: snesText }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: tracker.tempo = Math.max(40, tracker.tempo - 5)
                        }
                    }
                    Text {
                        text: tracker.tempo; font.family: pixelFont
                        font.pixelSize: 12; font.bold: true; color: snesCyan
                        Layout.preferredWidth: 30; horizontalAlignment: Text.AlignHCenter
                    }
                    Rectangle {
                        width: 28; height: 28; color: snesMidBlue; radius: 2
                        border.color: snesDarkBlue; border.width: 1
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 14; color: snesText }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: tracker.tempo = Math.min(240, tracker.tempo + 5)
                        }
                    }

                    Item { Layout.preferredWidth: 10 }

                    // Export
                    Rectangle {
                        Layout.preferredWidth: 80; Layout.preferredHeight: 34
                        color: "#2563eb"; border.color: Qt.lighter(color, 1.3)
                        border.width: 2; radius: 2
                        opacity: tracker.ready && !root.exporting ? 1.0 : 0.5
                        Text {
                            anchors.centerIn: parent
                            text: Qt.platform.os === "wasm" ? "💾 DL" : "💾 SAVE"
                            font.family: pixelFont; font.pixelSize: 10; font.bold: true; color: snesText
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: tracker.ready && !root.exporting
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.exporting = true; root.exportProgress = 0
                                exportTimer.start(); tracker.exportWav()
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            // INFO
            // ══════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 36
                color: snesDarkBlue; border.color: snesMidBlue; border.width: 2
                Text {
                    anchors.centerIn: parent
                    text: "SEED " + root.seed + " | " + currentEnv.toUpperCase() +
                          " | " + tracker.scale.toUpperCase() +
                          " | ROOT " + tracker.rootNote +
                          " | LEFT-CLICK: cycle note  RIGHT-CLICK: clear"
                    font.family: pixelFont; font.pixelSize: 8; color: snesDimText
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // EXPORT OVERLAY
    // ══════════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent; color: "#000000ee"; visible: root.exporting; z: 500
        Timer {
            id: exportTimer; interval: 150; repeat: true
            onTriggered: {
                root.exportProgress = Math.min(0.95, root.exportProgress + 0.02)
                if (root.exportProgress >= 0.95) { stop(); completeTimer.start() }
            }
        }
        Timer {
            id: completeTimer; interval: 2000
            onTriggered: { root.exporting = false; root.exportProgress = 0 }
        }
        Column {
            anchors.centerIn: parent; spacing: 16
            Text {
                text: "GENERATING WAV..."; font.family: pixelFont
                font.pixelSize: 18; font.bold: true; color: snesAccent
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                width: 280; height: 20; color: snesBlack
                border.color: snesAccent; border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter
                Row {
                    anchors.fill: parent; anchors.margins: 3
                    Repeater {
                        model: 20
                        Rectangle {
                            width: (parent.width) / 20 - 1; height: parent.height
                            color: index < Math.floor(root.exportProgress * 20) ? snesAccent : snesDarkBlue
                        }
                    }
                }
            }
            Text {
                text: Math.round(root.exportProgress * 100) + "%"
                font.family: pixelFont; font.pixelSize: 12; color: snesDimText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // RETRO SLIDER COMPONENT
    // ══════════════════════════════════════════════════════════
    component RetroSlider: Item {
        id: sliderRoot; height: 18
        property real value: 0.5
        property real from: 0.0
        property real to: 1.0
        property color barColor: snesAccent

        Rectangle {
            anchors.fill: parent; color: snesBlack
            border.color: snesMidBlue; border.width: 1
            Row {
                anchors.fill: parent; anchors.margins: 2
                Repeater {
                    model: 16
                    Rectangle {
                        width: (parent.width) / 16; height: parent.height
                        color: {
                            var nv = (sliderRoot.value - sliderRoot.from) / (sliderRoot.to - sliderRoot.from)
                            return index < Math.floor(nv * 16) ? sliderRoot.barColor : snesDarkBlue
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    sliderRoot.value = sliderRoot.from + (mouse.x / width) * (sliderRoot.to - sliderRoot.from)
                }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var r = Math.max(0, Math.min(1, mouse.x / width))
                        sliderRoot.value = sliderRoot.from + r * (sliderRoot.to - sliderRoot.from)
                    }
                }
            }
        }
    }
}
