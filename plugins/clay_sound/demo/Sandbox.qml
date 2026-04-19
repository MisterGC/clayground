// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Sound effects and music playback
// @tags Audio, Sound, Music
// @category Plugin Demos

import QtQuick
import QtQuick.Controls
import Clayground.Sound

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

    // --- Sound effects (Sound wrapper) -------------------------------
    Sound {
        id: clickSound
        source: "sound.wav"
        volume: volumeSlider.value
        onErrorOccurred: (msg) => statusText.text = "Sound Error: " + msg
        onFinished: console.log("Sound finished")
    }

    // --- Background music (Music wrapper) ----------------------------
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

    // --- SongPlayer demo ---------------------------------------------
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

    // --- Bake Lab (Synth ↔ Sample) -----------------------------------
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

    // --- Header ------------------------------------------------------
    Column {
        id: header
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
    }

    ScrollView {
        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.bottom: statusText.top
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        clip: true

        Column {
            width: parent.parent.width - 40
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
}
