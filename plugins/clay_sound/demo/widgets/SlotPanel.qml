// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SlotPanel — one "cartridge" bound to a live SynthInstrument.
//
// Layout matches the Studio mockup:
//   ┌──────────────────────────┐
//   │ TITLE                 ●● │  (title + power LEDs)
//   │ ┌──────────────────────┐ │
//   │ │       scope          │ │
//   │ └──────────────────────┘ │
//   │  amber LED bar           │
//   │  ┌────┐   ┌────┐         │
//   │  │knob│   │knob│         │  (role-dependent macro knobs)
//   │  └────┘   └────┘         │
//   │  LED       LED           │
//   │  ┌──────────────────────┐│
//   │  │ ADSR stepped graph   ││
//   │  └──────────────────────┘│
//   │  ┌──────────────────────┐│
//   │  │ PITCH stepped graph  ││
//   │  └──────────────────────┘│
//   └──────────────────────────┘
//
// The `role` property picks which two macro knobs are exposed; all
// slots show the ADSR + PITCH graphs derived from the live patch.

import QtQuick
import QtQuick.Layouts

RetroPanel {
    id: root

    property var instrument: null
    property string role: "kick"        // "kick" | "hat" | "lead" | "bass"
    // Optional row triggered LED indicator (pulse on play).
    property bool triggered: false
    // Colour accent for macro knobs / LED bar (default amber).
    property color accent: Retro.amber

    signal previewRequested
    signal bakeRequested

    titleColor: accent
    activeLeds: instrument ? Math.min(ledCount, instrument.activeVoices + 1) : 0

    // Per-slot scope samples. Recomputed whenever any relevant param
    // changes. Cheap (~250ms of mono audio at 44.1k = 11k samples).
    property var _scopeSamples: []
    readonly property string _watchKey:
        !instrument ? "" :
            instrument.waveform + "|" + instrument.attack + "|" +
            instrument.decay + "|" + instrument.sustain + "|" +
            instrument.release + "|" + instrument.pitchStart + "|" +
            instrument.pitchEnd + "|" + instrument.pitchTime + "|" +
            instrument.lfoRate + "|" + instrument.lfoDepth + "|" +
            instrument.lfoTarget
    on_WatchKeyChanged: _refreshScope()

    function _refreshScope() {
        if (!instrument) { _scopeSamples = []; return }
        _scopeSamples = instrument.renderPatchPreview(_previewNote(), 0.25, 1.0)
    }

    function _previewNote() {
        // Noise responds the same at any pitch; for others a mid-range
        // note shows the waveform clearly.
        if (role === "kick") return 36      // C2 — kick's natural territory
        if (role === "bass") return 43      // G2 — audible bass tone
        if (role === "hat")  return 60      // C4 — arbitrary for noise
        return 60                           // C4 — lead
    }

    // ADSR graph points: [0,0] → attack top → decay → sustain plateau → release drop.
    readonly property var _adsrPoints: {
        if (!instrument) return [[0, 0], [1, 0]]
        var a = instrument.attack
        var d = instrument.decay
        var s = instrument.sustain
        var r = instrument.release
        // Normalise the four segments into the 0..1 graph x-axis. Clamp
        // the release visually so it doesn't dominate when it's long.
        var total = Math.max(0.001, a + d + 0.4 + r)
        var xA = a / total
        var xD = (a + d) / total
        var xS = (a + d + 0.4) / total
        return [
            [0,  0],
            [xA, 1],
            [xD, s],
            [xS, s],
            [1,  0]
        ]
    }

    // Pitch graph: starts at 0.5 (centre = no offset), ramps up/down to
    // pitchStart, drifts to pitchEnd over pitchTime, then holds.
    readonly property var _pitchPoints: {
        if (!instrument) return [[0, 0.5], [1, 0.5]]
        var ps = instrument.pitchStart
        var pe = instrument.pitchEnd
        var pt = instrument.pitchTime
        // Map -24..+24 semitones to 0..1 graph y
        function n(v) { return Math.max(0, Math.min(1, 0.5 + v / 48.0)) }
        var xT = Math.max(0.02, Math.min(0.95, pt / 1.0))
        return [
            [0,   n(ps)],
            [xT,  n(pe)],
            [1,   n(pe)]
        ]
    }

    Component.onCompleted: _refreshScope()

    // Body
    ColumnLayout {
        anchors.fill: parent.body
        spacing: 4

        MiniScope {
            id: scope
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            samples: root._scopeSamples
            traceColor: root.accent
            traceDim: Qt.darker(root.accent, 2.2)
            trigger: root.triggered
        }
        LEDBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            count: 16
            active: root.instrument
                    ? (root.triggered ? 14 : Math.min(14, 2 + root.instrument.activeVoices * 4))
                    : 0
            colorOn: root.accent
        }

        // Macro knob row — per role
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            // Slot 1 — TUNE + DECAY
            RetroKnob {
                visible: root.role === "kick"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchEnd : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchEnd = v }
            }
            RetroKnob {
                visible: root.role === "kick"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "DECAY"
                from: 0; to: 1; steps: 32
                value: root.instrument ? root.instrument.decay : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.decay = v }
            }

            // Slot 2 — NOISE tail + RELEASE
            RetroKnob {
                visible: root.role === "hat"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "NOISE"
                from: 0; to: 1; steps: 32
                value: root.instrument ? root.instrument.sustain : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.sustain = v }
            }
            RetroKnob {
                visible: root.role === "hat"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "RELEASE"
                from: 0; to: 0.6; steps: 30
                value: root.instrument ? root.instrument.release : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.release = v }
            }

            // Slot 3 — TUNE + LFO
            RetroKnob {
                visible: root.role === "lead"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchStart : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchStart = v }
            }
            RetroKnob {
                visible: root.role === "lead"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "LFO"
                from: 0; to: 4; steps: 32
                value: root.instrument ? root.instrument.lfoDepth : 0
                accent: Retro.teal
                onValueEdited: (v) => {
                    if (root.instrument) {
                        root.instrument.lfoDepth = v
                        root.instrument.lfoRate = 5
                        root.instrument.lfoTarget = v > 0 ? "pitch" : "none"
                    }
                }
            }

            // Slot 4 — TUNE + GLIDE
            RetroKnob {
                visible: root.role === "bass"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchEnd : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchEnd = v }
            }
            RetroKnob {
                visible: root.role === "bass"
                Layout.preferredWidth: 56
                Layout.preferredHeight: 64
                label: "GLIDE"
                from: 0; to: 0.4; steps: 32
                value: root.instrument ? root.instrument.pitchTime : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchTime = v }
            }
        }

        // Short LED row under the knobs — a cheeky activity indicator.
        LEDBar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width * 0.8
            Layout.preferredHeight: 5
            count: 16
            active: root.triggered ? 16 : 0
            colorOn: Retro.red
            colorOff: Retro.redDim
            hotThreshold: 13
        }

        StepGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            label: "ADSR"
            points: root._adsrPoints
        }
        StepGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            label: "PITCH"
            points: root._pitchPoints
            traceColor: Retro.teal
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Rectangle {
                width: 28; height: 16
                color: "transparent"
                border.width: 1
                border.color: Retro.bevelHi
                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: Retro.amber
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsValue
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewRequested()
                }
            }
            Rectangle {
                width: 42; height: 16
                color: "transparent"
                border.width: 1
                border.color: Retro.bevelHi
                Text {
                    anchors.centerIn: parent
                    text: "BAKE"
                    color: Retro.teal
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsLabel
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.bakeRequested()
                }
            }
        }
    }
}
