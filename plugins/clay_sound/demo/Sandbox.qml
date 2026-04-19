// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Sound effects and music playback
// @tags Audio, Sound, Music
// @category Plugin Demos

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Sound
import "widgets" as W

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"
    focus: true

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Vim-mode flag (wired to RetroToggle in the Studio tab); keyboard
    // navigation logic comes in substage 5e.
    property bool vimMode: false

    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_F1) {
            helpOverlay.open = !helpOverlay.open
            ev.accepted = true
        } else if (ev.key === Qt.Key_F12) {
            root.vimMode = !root.vimMode
            ev.accepted = true
        } else if (ev.key === Qt.Key_Escape && helpOverlay.open) {
            helpOverlay.open = false
            ev.accepted = true
        }
    }

    // --- Basics: wrapper demos ---------------------------------------
    Sound {
        id: clickSound
        source: "sound.wav"
        volume: volumeSlider.value
        onErrorOccurred: (msg) => statusText.text = "Sound Error: " + msg
        onFinished: console.log("Sound finished")
    }
    Music {
        id: bgMusic
        source: "music.mp3"
        volume: volumeSlider.value
        loop: loopCheckbox.checked
        onStatusChanged: {
            if (bgMusic.status === 3)
                statusText.text = "Music Error: failed to load"
        }
        onFinished: console.log("Music finished")
    }

    // --- Basics: SongPlayer demo -------------------------------------
    SynthInstrument {
        id: songLead
        objectName: "demoLead"
        waveform: "triangle"
        attack: 0.005; decay: 0.08; sustain: 0.5; release: 0.15
        volume: volumeSlider.value
    }
    SynthInstrument {
        id: songBass
        objectName: "demoBass"
        waveform: "sawtooth"
        attack: 0.01; decay: 0.1; sustain: 0.6; release: 0.2
        volume: volumeSlider.value * 0.6
    }
    SongPlayer {
        id: songPlayer
        source: "songs/demo.song.json"
        instruments: [songLead, songBass]
        loop: songLoopCheckbox.checked
        onParseError: (msg) => statusText.text = "Song parse error: " + msg
        onHotReloaded: statusText.text = "Song hot-reloaded"
    }

    // --- Basics: Bake Lab (retained for reference) -------------------
    SynthInstrument {
        id: bakeSource
        waveform: "square"
        attack: 0.002; decay: 0.05; sustain: 0.7; release: 0.15
        pitchStart: 4; pitchEnd: 0; pitchTime: 0.08
        volume: volumeSlider.value
    }
    SampleInstrument {
        id: bakeSample
        volume: volumeSlider.value
    }

    // --- Studio: Sample Bank (4 slots, editable live) ----------------
    // Each slot IS a SynthInstrument — editing its properties while the
    // tracker loops means the next trigger uses the new patch.
    SynthInstrument {
        id: slot0
        waveform: "sawtooth"
        attack: 0.002; decay: 0.15; sustain: 0.0; release: 0.05
        pitchStart: 12; pitchEnd: -4; pitchTime: 0.12
        volume: volumeSlider.value
    }
    SynthInstrument {
        id: slot1
        waveform: "noise"
        attack: 0.002; decay: 0.08; sustain: 0.0; release: 0.05
        pitchStart: 0; pitchEnd: 0; pitchTime: 0
        volume: volumeSlider.value * 0.7
    }
    SynthInstrument {
        id: slot2
        waveform: "square"
        attack: 0.003; decay: 0.06; sustain: 0.45; release: 0.1
        pitchStart: 0; pitchEnd: 0; pitchTime: 0
        volume: volumeSlider.value
    }
    SynthInstrument {
        id: slot3
        waveform: "triangle"
        attack: 0.005; decay: 0.12; sustain: 0.55; release: 0.18
        pitchStart: 0; pitchEnd: 0; pitchTime: 0
        volume: volumeSlider.value
    }
    property var _bankSlots: [slot0, slot1, slot2, slot3]
    property var _bankNames: ["S1 · kick", "S2 · hat", "S3 · lead", "S4 · bass"]

    // --- Shared header (volume + tabs) -------------------------------
    Column {
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Text {
            text: "Clayground.Sound"
            color: root.accentColor
            font.family: root.monoFont
            font.pixelSize: 20
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Text {
                text: "Volume:"
                color: root.textColor
                font.family: root.monoFont
                anchors.verticalCenter: parent.verticalCenter
            }
            Slider {
                id: volumeSlider
                width: 200
                from: 0; to: 1; value: 0.8
            }
            Text {
                text: Math.round(volumeSlider.value * 100) + "%"
                color: root.textColor
                font.family: root.monoFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TabBar {
            id: tabs
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.5
            TabButton { text: "Studio" }
            TabButton { text: "Basics" }
        }
    }

    StackLayout {
        anchors.top: parent.top
        anchors.topMargin: 130
        anchors.bottom: statusText.top
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: parent.width * 0.1
        anchors.rightMargin: parent.width * 0.1
        // Tab 0 = Studio (shown second in StackLayout), tab 1 = Basics
        currentIndex: tabs.currentIndex === 0 ? 1 : 0

        // =============================================================
        // Tab 1 — Basics
        // =============================================================
        ScrollView {
            clip: true
            Column {
                width: parent.parent.width
                spacing: 16

                // Sound Effects
                Rectangle {
                    width: parent.width
                    height: soundColumn.height + 30
                    color: root.surfaceColor
                    radius: 8
                    Column {
                        id: soundColumn
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: "Sound Effects"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.pixelSize: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Row {
                            spacing: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            Button { text: "Play Sound"; onClicked: clickSound.play() }
                            Button { text: "Stop All"; onClicked: clickSound.stop() }
                            Button {
                                text: "Rapid Fire (5x)"
                                onClicked: {
                                    for (let i = 0; i < 5; i++)
                                        Qt.callLater(() => clickSound.play())
                                }
                            }
                        }
                        Text {
                            text: "Loaded: " + clickSound.loaded + " | Status: " + clickSound.status
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Background Music
                Rectangle {
                    width: parent.width
                    height: musicColumn.height + 30
                    color: root.surfaceColor
                    radius: 8
                    Column {
                        id: musicColumn
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: "Background Music"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.pixelSize: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Row {
                            spacing: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            Button {
                                text: bgMusic.playing ? "Playing..." : "Play"
                                enabled: !bgMusic.playing
                                onClicked: bgMusic.play()
                            }
                            Button { text: "Pause"; onClicked: bgMusic.pause(); enabled: bgMusic.playing }
                            Button { text: "Stop"; onClicked: bgMusic.stop() }
                        }
                        Row {
                            spacing: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            CheckBox {
                                id: loopCheckbox
                                text: "Loop"
                                checked: false
                                contentItem: Text {
                                    text: loopCheckbox.text
                                    color: root.textColor
                                    font.family: root.monoFont
                                    leftPadding: loopCheckbox.indicator.width + 5
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                        Text {
                            text: "Playing: " + bgMusic.playing +
                                  " | Paused: " + bgMusic.paused +
                                  " | Duration: " + bgMusic.duration + "ms"
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Instrument Lab
                Rectangle {
                    width: parent.width
                    height: synthColumn.height + 30
                    color: root.surfaceColor
                    radius: 8

                    SynthInstrument {
                        id: hop
                        waveform: "square"
                        attack: 0.003; decay: 0.05; sustain: 0.4; release: 0.08
                        pitchStart: 12; pitchEnd: 0; pitchTime: 0.12
                        volume: volumeSlider.value
                    }

                    Column {
                        id: synthColumn
                        anchors.centerIn: parent
                        spacing: 10
                        width: parent.width - 30
                        Text {
                            text: "Instrument Lab — SynthInstrument"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Text { text: "Waveform:"; color: root.textColor; font.family: root.monoFont; anchors.verticalCenter: parent.verticalCenter }
                            ComboBox {
                                model: ["sine", "square", "triangle", "sawtooth", "noise"]
                                currentIndex: 1
                                onCurrentTextChanged: hop.waveform = currentText
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Button { text: "Hop"
                                     onClicked: { hop.triggerNote(72, 0.9, 0.15); statusText.text = "hop" } }
                            Button { text: "Coin"
                                     onClicked: {
                                         hop.waveform = "square"
                                         hop.pitchStart = 0; hop.pitchEnd = 0; hop.pitchTime = 0
                                         hop.triggerNote(84, 0.9, 0.08)
                                         timerC.start()
                                         statusText.text = "coin"
                                     }
                            }
                            Timer { id: timerC; interval: 80; onTriggered: hop.triggerNote(88, 0.9, 0.12) }
                            Button { text: "Splash"
                                     onClicked: {
                                         hop.waveform = "noise"
                                         hop.pitchStart = 0; hop.pitchEnd = 0; hop.pitchTime = 0
                                         hop.release = 0.3
                                         hop.triggerNote(60, 0.7, 0.3)
                                         statusText.text = "splash"
                                     } }
                            Button { text: "Melody"
                                     onClicked: {
                                         hop.waveform = "triangle"
                                         hop.pitchStart = 0; hop.pitchEnd = 0; hop.pitchTime = 0
                                         var notes = [60, 64, 67, 72]
                                         for (var i = 0; i < notes.length; ++i)
                                             hopDelay.createObject(root, { note: notes[i], t: i * 120 })
                                         statusText.text = "melody"
                                     } }
                        }
                        Text {
                            text: "Active voices: " + hop.activeVoices
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    Component {
                        id: hopDelay
                        Timer {
                            property int note: 60
                            property int t: 0
                            interval: t
                            running: true
                            onTriggered: { hop.triggerNote(note, 0.9, 0.2); destroy() }
                        }
                    }
                }

                // Pattern Lab — SongPlayer
                Rectangle {
                    width: parent.width
                    height: patternColumn.height + 30
                    color: root.surfaceColor
                    radius: 8
                    Column {
                        id: patternColumn
                        anchors.centerIn: parent
                        spacing: 10
                        width: parent.width - 30
                        Text {
                            text: "Pattern Lab — SongPlayer"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "source: " + songPlayer.source
                                  + "  (edit live; .dojoignore protects from reload)"
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                            wrapMode: Text.Wrap
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Button { text: songPlayer.playing ? "Playing..." : "Play"
                                     enabled: !songPlayer.playing && songPlayer.loaded
                                     onClicked: songPlayer.play() }
                            Button { text: "Pause"
                                     enabled: songPlayer.playing
                                     onClicked: songPlayer.pause() }
                            Button { text: "Stop"; onClicked: songPlayer.stop() }
                            CheckBox {
                                id: songLoopCheckbox
                                text: "Loop"
                                checked: true
                                contentItem: Text {
                                    text: songLoopCheckbox.text
                                    color: root.textColor
                                    font.family: root.monoFont
                                    leftPadding: songLoopCheckbox.indicator.width + 5
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Text {
                                text: "pos: " + songPlayer.position.toFixed(2) +
                                      " / " + songPlayer.totalBeats.toFixed(1) + " beats"
                                color: root.dimTextColor
                                font.family: root.monoFont
                                font.pixelSize: 11
                            }
                            Text {
                                text: "tempo: " + songPlayer.tempo.toFixed(0) + " BPM"
                                color: root.dimTextColor
                                font.family: root.monoFont
                                font.pixelSize: 11
                            }
                            Text {
                                text: "loaded: " + songPlayer.loaded
                                color: songPlayer.loaded ? "#4ade80" : "#f87171"
                                font.family: root.monoFont
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                // Bake Lab
                Rectangle {
                    width: parent.width
                    height: bakeColumn.height + 30
                    color: root.surfaceColor
                    radius: 8
                    Column {
                        id: bakeColumn
                        anchors.centerIn: parent
                        spacing: 10
                        width: parent.width - 30
                        Text {
                            text: "Bake Lab — Synth ↔ Sample"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Button { text: "Trigger synth"
                                     onClicked: bakeSource.triggerNote(69, 0.9, 0.4) }
                            Button {
                                text: "Bake to WAV"
                                onClicked: {
                                    var p = bakeSource.bake(69, 0.4, 0.9)
                                    if (!p.length) { statusText.text = "Bake failed"; return }
                                    bakeSample.source = "file://" + p
                                    statusText.text = "Baked: " + p
                                }
                            }
                            Button { text: "Trigger baked sample"
                                     enabled: bakeSample.loaded
                                     onClicked: bakeSample.triggerOneShot(0.9) }
                        }
                        Text {
                            text: bakeSample.loaded
                                  ? "Sample: " + bakeSample.source
                                  : "Sample: (bake first)"
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                            wrapMode: Text.Wrap
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        // =============================================================
        // Tab 2 — Studio (Sample Bank + Tracker)
        // =============================================================
        ScrollView {
            clip: true
            Column {
                width: parent.parent.width
                spacing: 16

                // ------- Widget preview (5a smoke) --------------------
                Rectangle {
                    width: parent.width
                    height: 240
                    color: root.surfaceColor
                    radius: 8
                    Row {
                        anchors.centerIn: parent
                        spacing: 16

                        W.RetroPanel {
                            width: 260; height: 200
                            title: "S1 KICK"
                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6
                                W.MiniScope {
                                    id: previewScope
                                    width: parent.width
                                    height: 50
                                    samples: {
                                        // Build a simple test wave (two cycles of a decaying sine)
                                        var out = []
                                        for (var i = 0; i < 256; ++i) {
                                            var t = i / 256
                                            out.push(Math.sin(t * Math.PI * 8) * (1 - t))
                                        }
                                        return out
                                    }
                                }
                                W.LEDBar {
                                    width: parent.width; height: 8
                                    count: 16; active: 9.4
                                }
                                Row {
                                    spacing: 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    W.RetroKnob {
                                        width: 64; height: 70
                                        label: "TUNE"
                                        from: -24; to: 24; steps: 48
                                        value: 3
                                    }
                                    W.RetroKnob {
                                        width: 64; height: 70
                                        label: "DECAY"
                                        from: 0; to: 1; steps: 24
                                        value: 0.3
                                        accent: W.Retro.pink
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: 10
                            W.StepGraph {
                                width: 200; height: 64
                                label: "ADSR"
                                points: [[0, 0], [0.12, 1], [0.3, 0.6], [0.78, 0.6], [1, 0]]
                            }
                            W.StepGraph {
                                width: 200; height: 54
                                label: "PITCH"
                                points: [[0, 0.55], [0.08, 0.9], [0.4, 0.5], [1, 0.5]]
                                traceColor: W.Retro.teal
                            }
                            Row {
                                spacing: 4
                                Repeater {
                                    model: ["C2", "---", "Eb3", "G4"]
                                    W.StepCell {
                                        label: modelData
                                        active: modelData !== "---"
                                        beat: index % 2 === 0
                                        playhead: index === 2
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: 10
                            W.CartridgeButton {
                                width: 160; height: 34
                                tag: "01"; label: "CHIP RALLY"
                                selected: true
                            }
                            W.CartridgeButton {
                                width: 160; height: 34
                                tag: "02"; label: "NEON CLUB"
                            }
                            W.CartridgeButton {
                                width: 160; height: 34
                                tag: "03"; label: "BOSS FIGHT"
                            }
                            W.RetroToggle {
                                width: 130; height: 28
                                leftLabel: "MOUSE"; rightLabel: "VIM"
                                checked: vimMode
                                onToggled: (v) => vimMode = v
                            }
                            Button {
                                text: "? Help (F1)"
                                onClicked: helpOverlay.open = true
                            }
                        }
                    }
                }

                // ------- Sample Bank ----------------------------------
                Rectangle {
                    width: parent.width
                    height: bankColumn.height + 30
                    color: root.surfaceColor
                    radius: 8
                    Column {
                        id: bankColumn
                        anchors.centerIn: parent
                        spacing: 8
                        width: parent.width - 30

                        Text {
                            text: "Sample Bank — 4 live patches"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "edit a slot while the tracker loops — next trigger picks up your change"
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            wrapMode: Text.Wrap
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Repeater {
                            model: 4
                            Rectangle {
                                readonly property int slotIdx: index
                                readonly property var inst: root._bankSlots[slotIdx]
                                width: bankColumn.width
                                height: slotColumn.height + 14
                                color: "#1f2a44"
                                radius: 4

                                Column {
                                    id: slotColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 4

                                    Row {
                                        spacing: 10
                                        width: parent.width
                                        Text {
                                            text: root._bankNames[slotIdx]
                                            color: root.accentColor
                                            font.family: root.monoFont
                                            font.bold: true
                                            font.pixelSize: 12
                                            width: 110
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        ComboBox {
                                            model: ["sine", "square", "triangle", "sawtooth", "noise"]
                                            currentIndex: ["sine","square","triangle","sawtooth","noise"].indexOf(inst.waveform)
                                            width: 110
                                            onCurrentTextChanged: inst.waveform = currentText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Button {
                                            text: "▶"
                                            width: 32
                                            onClicked: inst.triggerNote(60, 0.9, 0.3)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Button {
                                            text: "Bake"
                                            onClicked: {
                                                var p = inst.bake(60, 0.5, 0.9)
                                                statusText.text = p.length
                                                    ? "Baked " + root._bankNames[slotIdx] + " → " + p
                                                    : "Bake failed"
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        width: parent.width
                                        Text { text: "A";   color: root.dimTextColor; font.family: root.monoFont; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 90; from: 0; to: 0.3; value: inst.attack;  onValueChanged: inst.attack  = value; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "D";   color: root.dimTextColor; font.family: root.monoFont; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 90; from: 0; to: 0.5; value: inst.decay;   onValueChanged: inst.decay   = value; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "S";   color: root.dimTextColor; font.family: root.monoFont; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 90; from: 0; to: 1.0; value: inst.sustain; onValueChanged: inst.sustain = value; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "R";   color: root.dimTextColor; font.family: root.monoFont; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 90; from: 0; to: 0.8; value: inst.release; onValueChanged: inst.release = value; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "Pitch→";  color: root.dimTextColor; font.family: root.monoFont; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 80; from: -24; to: 24; stepSize: 1; value: inst.pitchStart; onValueChanged: inst.pitchStart = value; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 80; from: -24; to: 24; stepSize: 1; value: inst.pitchEnd;   onValueChanged: inst.pitchEnd   = value; anchors.verticalCenter: parent.verticalCenter }
                                        Slider { width: 60; from: 0;  to: 1;  value: inst.pitchTime; onValueChanged: inst.pitchTime = value; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }
                    }
                }

                // ------- Tracker --------------------------------------
                Rectangle {
                    id: tracker
                    width: parent.width
                    height: trackerColumn.height + 30
                    color: root.surfaceColor
                    radius: 8

                    readonly property var palette: [
                        -1,
                        24, 27, 29, 31, 34,
                        36, 39, 41, 43, 46,
                        48, 51, 53, 55, 58,
                        60, 63, 65, 67, 70,
                        72, 75
                    ]
                    readonly property var paletteLabels: [
                        "---",
                        "C2", "Eb2", "F2", "G2", "Bb2",
                        "C3", "Eb3", "F3", "G3", "Bb3",
                        "C4", "Eb4", "F4", "G4", "Bb4",
                        "C5", "Eb5", "F5", "G5", "Bb5",
                        "C6", "Eb6"
                    ]
                    property int stepCount: 16
                    readonly property int trackCount: 4
                    // Cells get smaller for long patterns so 32-step still fits.
                    readonly property int cellWidth:
                        stepCount <= 16 ? 38 : Math.max(18, Math.floor(640 / stepCount))

                    property int  step: -1
                    property bool playing: false
                    property bool loop: true
                    property int  bpm: 130
                    property string presetName: "(user)"
                    // tracks[row] = Array(stepCount) of palette indices (0..N-1)
                    property var  tracks: [
                        Array(16).fill(0),
                        Array(16).fill(0),
                        Array(16).fill(0),
                        Array(16).fill(0)
                    ]

                    onStepCountChanged: resizeTracksTo(stepCount)

                    function resizeTracksTo(newCount) {
                        var all = []
                        for (var r = 0; r < trackCount; ++r) {
                            var old = tracks[r] || []
                            var next = old.slice(0, newCount)
                            while (next.length < newCount) next.push(0)
                            all.push(next)
                        }
                        tracks = all
                        if (step >= newCount) { playing = false; step = -1 }
                    }

                    function cellSet(row, idx, paletteIdx) {
                        var arr = tracks[row].slice()
                        var palN = palette.length
                        arr[idx] = ((paletteIdx % palN) + palN) % palN
                        var all = tracks.slice()
                        all[row] = arr
                        tracks = all
                    }
                    function cellCycleUp(row, idx) {
                        cellSet(row, idx, (tracks[row][idx] + 1) % palette.length)
                    }
                    function cellClear(row, idx) {
                        cellSet(row, idx, 0)
                    }
                    function clearAll() {
                        var all = []
                        for (var i = 0; i < trackCount; ++i) all.push(Array(stepCount).fill(0))
                        tracks = all
                    }

                    function applyPreset(name) {
                        if (name === "psy") {
                            bpm = 145
                            presetName = "psy trance"
                            stepCount = 16
                            // Slot 0 — deep saw kick with snappy pitch drop
                            slot0.waveform = "sawtooth"
                            slot0.attack = 0.001; slot0.decay = 0.10; slot0.sustain = 0.0; slot0.release = 0.05
                            slot0.pitchStart = 12; slot0.pitchEnd = -4; slot0.pitchTime = 0.08
                            // Slot 1 — tight noise hat
                            slot1.waveform = "noise"
                            slot1.attack = 0.001; slot1.decay = 0.04; slot1.sustain = 0.0; slot1.release = 0.02
                            slot1.pitchStart = 0; slot1.pitchEnd = 0; slot1.pitchTime = 0
                            // Slot 2 — bright saw lead
                            slot2.waveform = "sawtooth"
                            slot2.attack = 0.005; slot2.decay = 0.15; slot2.sustain = 0.3; slot2.release = 0.08
                            slot2.pitchStart = 0; slot2.pitchEnd = 0; slot2.pitchTime = 0
                            // Slot 3 — rolling saw bass
                            slot3.waveform = "sawtooth"
                            slot3.attack = 0.001; slot3.decay = 0.05; slot3.sustain = 0.4; slot3.release = 0.04
                            slot3.pitchStart = 0; slot3.pitchEnd = 0; slot3.pitchTime = 0
                            // 4-on-the-floor kick, offbeat hats, sparse lead, rolling 16ths bass
                            var k = Array(16).fill(0); k[0]=6; k[4]=6; k[8]=6; k[12]=6
                            var h = Array(16).fill(0); h[2]=12; h[6]=12; h[10]=12; h[14]=12
                            var l = Array(16).fill(0); l[3]=19; l[11]=18  // G4, F4
                            var b = Array(16).fill(0)
                            for (var i = 0; i < 16; ++i) if (i % 4 !== 0) b[i] = 6  // C2 everywhere except kick slots
                            tracks = [k, h, l, b]
                        } else if (name === "house") {
                            bpm = 124
                            presetName = "classic house"
                            stepCount = 16
                            // Slot 0 — soft sine kick
                            slot0.waveform = "sine"
                            slot0.attack = 0.002; slot0.decay = 0.12; slot0.sustain = 0.0; slot0.release = 0.08
                            slot0.pitchStart = 6; slot0.pitchEnd = -2; slot0.pitchTime = 0.1
                            // Slot 1 — clap-flavoured noise
                            slot1.waveform = "noise"
                            slot1.attack = 0.003; slot1.decay = 0.08; slot1.sustain = 0.0; slot1.release = 0.04
                            slot1.pitchStart = 0; slot1.pitchEnd = 0; slot1.pitchTime = 0
                            // Slot 2 — warm triangle lead
                            slot2.waveform = "triangle"
                            slot2.attack = 0.01; slot2.decay = 0.1; slot2.sustain = 0.5; slot2.release = 0.15
                            slot2.pitchStart = 0; slot2.pitchEnd = 0; slot2.pitchTime = 0
                            // Slot 3 — round triangle bass
                            slot3.waveform = "triangle"
                            slot3.attack = 0.005; slot3.decay = 0.15; slot3.sustain = 0.55; slot3.release = 0.18
                            slot3.pitchStart = 0; slot3.pitchEnd = 0; slot3.pitchTime = 0
                            // 4-on-the-floor kick, claps on 2&4, sparse lead, offbeat bass line
                            var kk = Array(16).fill(0); kk[0]=6; kk[4]=6; kk[8]=6; kk[12]=6
                            var cp = Array(16).fill(0); cp[4]=16; cp[12]=16                // C4 clap
                            var ll = Array(16).fill(0); ll[6]=19; ll[14]=20                // G4, Bb4
                            var bb = Array(16).fill(0); bb[2]=6; bb[6]=8; bb[10]=6; bb[14]=9  // C2, F2, C2, G2
                            tracks = [kk, cp, ll, bb]
                        }
                    }
                    function fireStep() {
                        var i = step
                        if (i < 0) return
                        for (var r = 0; r < trackCount; ++r) {
                            var p = tracks[r][i]
                            if (p > 0) root._bankSlots[r].triggerNote(palette[p], 0.85, 0.25)
                        }
                    }

                    Timer {
                        id: stepTimer
                        interval: 60000 / tracker.bpm / 4
                        repeat: true
                        running: tracker.playing
                        onTriggered: {
                            var next = tracker.step + 1
                            if (next >= tracker.stepCount) {
                                if (!tracker.loop) { tracker.playing = false; tracker.step = -1; return }
                                next = 0
                            }
                            tracker.step = next
                            tracker.fireStep()
                        }
                    }

                    Column {
                        id: trackerColumn
                        anchors.centerIn: parent
                        spacing: 10
                        width: parent.width - 30

                        Text {
                            text: "Tracker — 16 steps × 4 tracks (each track plays its bank slot)"
                            color: root.accentColor
                            font.family: root.monoFont
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            Button {
                                text: tracker.playing ? "Playing..." : "Play"
                                enabled: !tracker.playing
                                onClicked: { tracker.step = -1; tracker.playing = true }
                            }
                            Button { text: "Stop"; onClicked: { tracker.playing = false; tracker.step = -1 } }
                            Button { text: "Clear"; onClicked: tracker.clearAll() }
                            CheckBox {
                                id: trkLoopChk
                                text: "Loop"
                                checked: tracker.loop
                                onCheckedChanged: tracker.loop = checked
                                contentItem: Text {
                                    text: trkLoopChk.text
                                    color: root.textColor
                                    font.family: root.monoFont
                                    leftPadding: trkLoopChk.indicator.width + 5
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Text {
                                text: "BPM: " + tracker.bpm
                                color: root.textColor
                                font.family: root.monoFont
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Slider {
                                width: 200
                                from: 60; to: 220; stepSize: 1
                                value: tracker.bpm
                                onValueChanged: tracker.bpm = Math.round(value)
                            }
                            Text {
                                text: "Length:"
                                color: root.textColor
                                font.family: root.monoFont
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            ComboBox {
                                width: 70
                                model: [8, 16, 32]
                                currentIndex: model.indexOf(tracker.stepCount)
                                onCurrentTextChanged: {
                                    var n = parseInt(currentText)
                                    if (!isNaN(n) && n !== tracker.stepCount)
                                        tracker.stepCount = n
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Text {
                                text: "Preset:"
                                color: root.textColor
                                font.family: root.monoFont
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Button {
                                text: "Psy Trance"
                                onClicked: { tracker.applyPreset("psy"); statusText.text = "preset: psy trance" }
                            }
                            Button {
                                text: "House"
                                onClicked: { tracker.applyPreset("house"); statusText.text = "preset: classic house" }
                            }
                            Text {
                                text: "→ " + tracker.presetName
                                color: root.dimTextColor
                                font.family: root.monoFont
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Repeater {
                            model: tracker.trackCount
                            Row {
                                readonly property int rowIdx: index
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2
                                Text {
                                    text: root._bankNames[rowIdx].substring(0, 2)
                                    color: root.accentColor
                                    font.family: root.monoFont
                                    font.bold: true
                                    font.pixelSize: 10
                                    width: 32
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Repeater {
                                    model: tracker.stepCount
                                    Rectangle {
                                        readonly property int  stepIdx: index
                                        readonly property int  paletteIdx: tracker.tracks[parent.rowIdx][stepIdx]
                                        readonly property bool isCurrent: tracker.step === stepIdx
                                        readonly property bool isBeat: (stepIdx % 4) === 0
                                        width: tracker.cellWidth; height: 22
                                        radius: 3
                                        color: isCurrent ? "#ff3366"
                                                         : (paletteIdx > 0 ? "#0f9d9a"
                                                                           : (isBeat ? "#2a3246" : "#1a2234"))
                                        border.color: isBeat ? "#3f4b68" : "#2a3246"
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: tracker.paletteLabels[paletteIdx]
                                            color: paletteIdx > 0 ? "#ffffff" : root.dimTextColor
                                            font.family: root.monoFont
                                            font.pixelSize: 10
                                            font.bold: paletteIdx > 0
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onPressed: (ev) => {
                                                tracker.presetName = "(user)"
                                                if (ev.button === Qt.RightButton)
                                                    tracker.cellClear(parent.parent.rowIdx, stepIdx)
                                                else
                                                    tracker.cellCycleUp(parent.parent.rowIdx, stepIdx)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            text: "left-click cell: cycle note up · right-click: clear cell"
                            color: root.dimTextColor
                            font.family: root.monoFont
                            font.pixelSize: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    Text {
        id: statusText
        text: "Ready"
        color: "#4ade80"
        font.family: root.monoFont
        font.pixelSize: 12
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
    }

    W.HelpOverlay {
        id: helpOverlay
        onClosed: root.forceActiveFocus()
    }
}
