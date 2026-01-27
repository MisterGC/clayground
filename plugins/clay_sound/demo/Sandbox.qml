// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Sound effects and music playback
// @tags Audio, Sound, Music

import QtQuick
import QtQuick.Controls
import Clayground.Sound

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Test sound effect
    Sound {
        id: clickSound
        source: "https://raw.githubusercontent.com/MisterGC/ld46-keep-it-alive/master/src/sound/munching.wav"
        volume: volumeSlider.value
        onErrorOccurred: (msg) => statusText.text = "Sound Error: " + msg
        onFinished: console.log("Sound finished")
    }

    // Test background music (using a short sound as placeholder)
    Music {
        id: bgMusic
        source: "https://raw.githubusercontent.com/MisterGC/ld46-keep-it-alive/master/src/sound/munching.wav"
        volume: volumeSlider.value
        loop: loopCheckbox.checked
        onErrorOccurred: (msg) => statusText.text = "Music Error: " + msg
        onFinished: console.log("Music finished")
    }

    Column {
        anchors.centerIn: parent
        spacing: 20
        width: parent.width * 0.8

        Text {
            text: "Clayground.Sound"
            color: root.accentColor
            font.family: root.monoFont
            font.pixelSize: 20
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Volume control
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
                from: 0
                to: 1
                value: 0.8
            }

            Text {
                text: Math.round(volumeSlider.value * 100) + "%"
                color: root.textColor
                font.family: root.monoFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Sound Effects section
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

                    Button {
                        text: "Play Sound"
                        onClicked: clickSound.play()
                    }

                    Button {
                        text: "Stop All"
                        onClicked: clickSound.stop()
                    }

                    Button {
                        text: "Rapid Fire (5x)"
                        onClicked: {
                            for (let i = 0; i < 5; i++) {
                                Qt.callLater(() => clickSound.play())
                            }
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

        // Music section
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
                        onClicked: bgMusic.play()
                        enabled: !bgMusic.playing
                    }

                    Button {
                        text: "Pause"
                        onClicked: bgMusic.pause()
                        enabled: bgMusic.playing
                    }

                    Button {
                        text: "Stop"
                        onClicked: bgMusic.stop()
                    }
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

        // Status
        Text {
            id: statusText
            text: "Ready"
            color: "#4ade80"
            font.family: root.monoFont
            font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
