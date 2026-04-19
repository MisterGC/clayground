// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Modal help overlay that explains the Studio UI. Opens with F1 or the
// `?` button in the header. Closes with Esc / F1 / click-outside.
//
// The content is divided into three columns: WHAT IS THIS, MOUSE, and
// KEYBOARD (including vim-mode commands). A small "back" hint in the
// footer tells the user how to dismiss.

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool open: false

    signal closed

    anchors.fill: parent
    visible: open
    z: 1000

    function toggle() { open = !open; if (!open) root.closed() }
    function close()  { open = false; root.closed() }

    // Dim background — click to close
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.78
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Main panel
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 960)
        height: Math.min(parent.height * 0.9, 620)
        color: Retro.panel
        border.color: Retro.teal
        border.width: 2
        radius: 4

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            color: "transparent"
            border.color: Retro.bevelLo
            border.width: 1
            radius: 3
        }

        // Scan overlay for retro vibe
        Repeater {
            model: Math.floor(panel.height / 3)
            Rectangle {
                y: index * 3
                width: panel.width
                height: 1
                color: "#ffffff"
                opacity: 0.03
            }
        }

        // Header strip
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            height: 30
            color: Retro.panelHi
            border.color: Retro.bevelLo
            border.width: 1
            radius: 2

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 1; color: Retro.red;   anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 1; color: Retro.amber; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 1; color: Retro.green; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "HELP · CLAYGROUND.SOUND STUDIO"
                    color: Retro.teal
                    font.family: Retro.mono
                    font.bold: true
                    font.pixelSize: Retro.fsHeader
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10
                text: "[F1] / [Esc] / click outside to close"
                color: Retro.txtDim
                font.family: Retro.mono
                font.pixelSize: Retro.fsLabel
            }
        }

        // Body — three columns
        RowLayout {
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            anchors.topMargin: 10
            spacing: 14

            // ---- WHAT IS THIS ----
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 280
                spacing: 8

                Text {
                    text: "WHAT IS THIS"
                    color: Retro.amber
                    font.family: Retro.mono
                    font.bold: true
                    font.pixelSize: Retro.fsHeader
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Retro.txt
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsLabel
                    text: "A 90s-flavoured pocket sound workstation. Design four\n" +
                          "live synth patches (S1-S4), sequence them on a 16+ step\n" +
                          "grid, and load genre cartridges to start fast.\n\n" +
                          "Every slot is a real-time SynthInstrument — change a\n" +
                          "knob while the loop plays and the next trigger is\n" +
                          "shaped by the new value. No bake step required.\n\n" +
                          "The scope at the top of each slot draws the canonical\n" +
                          "response of the patch. It updates whenever you edit a\n" +
                          "parameter and flashes when the slot is triggered."
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Retro.txtDim
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsLabel
                    text: "LEGEND\n" +
                          " teal   parameters / envelopes\n" +
                          " amber  audio signal (scope, LEDs)\n" +
                          " pink   time / playhead / trigger flash\n" +
                          " red    hot / clipping / danger\n" +
                          " green  ready / OK / mode indicator"
                }
            }

            // ---- MOUSE ----
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 280
                spacing: 8

                Text {
                    text: "MOUSE"
                    color: Retro.amber
                    font.family: Retro.mono
                    font.bold: true
                    font.pixelSize: Retro.fsHeader
                }
                Text {
                    width: parent.width
                    color: Retro.txt
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsLabel
                    wrapMode: Text.WordWrap
                    text: "SAMPLE BANK (S1-S4)\n" +
                          " drag knob    ·  change value\n" +
                          " shift+drag   ·  fine precision\n" +
                          " wheel on knob·  step by one\n" +
                          " play button  ·  preview the slot\n" +
                          " bake button  ·  freeze current patch to WAV\n\n" +
                          "TRACKER\n" +
                          " left click   ·  cycle note up\n" +
                          " right click  ·  clear cell\n" +
                          " cartridge    ·  load full preset (slots + grid + BPM)\n" +
                          " PLAY / STOP  ·  transport\n" +
                          " CLEAR        ·  wipe the whole grid\n" +
                          " LENGTH combo ·  8 · 16 · 32 steps\n" +
                          " BPM slider   ·  60 - 220 BPM"
                }
            }

            // ---- KEYBOARD (incl. Vim mode) ----
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 280
                spacing: 8

                Text {
                    text: "KEYBOARD"
                    color: Retro.amber
                    font.family: Retro.mono
                    font.bold: true
                    font.pixelSize: Retro.fsHeader
                }
                Text {
                    width: parent.width
                    color: Retro.txt
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsLabel
                    wrapMode: Text.WordWrap
                    text: "ALWAYS\n" +
                          " F1           ·  toggle this help\n" +
                          " F12          ·  toggle Vim mode\n" +
                          " Space        ·  play / stop\n" +
                          " Esc          ·  close help / back to Normal\n\n" +
                          "VIM MODE (top-right switch)\n" +
                          " h j k l      ·  cursor left/down/up/right\n" +
                          " 0 / $        ·  row start / end\n" +
                          " w / b        ·  next / prev beat\n" +
                          " x            ·  clear cell\n" +
                          " r <key>      ·  replace cell with note\n" +
                          " i            ·  insert mode (keys cycle notes)\n" +
                          " d d          ·  clear entire row\n" +
                          " y y / p      ·  yank / paste row\n" +
                          " :            ·  command line\n\n" +
                          "COMMANDS (planned for next substage)\n" +
                          " :bpm 140     ·  set tempo\n" +
                          " :length 32   ·  set pattern length\n" +
                          " :preset psy  ·  load cartridge\n" +
                          " :w song.json ·  export to a song file"
                }
            }
        }

        // Footer
        Rectangle {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            height: 26
            color: Retro.panelHi
            border.color: Retro.bevelLo
            border.width: 1
            radius: 2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                text: "clayground.sound · hybrid synth / sampler / tracker · mit"
                color: Retro.txtDim
                font.family: Retro.mono
                font.pixelSize: Retro.fsLabel
            }
        }
    }

    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_F1) {
            root.close()
            ev.accepted = true
        }
    }
    focus: open
}
