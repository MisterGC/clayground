// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SlotPanel — one rack-mount "cartridge strip" bound to a live
// SynthInstrument. Designed to stack vertically so slot rows align
// with the tracker rows (S1-S4 top-to-bottom in both sections).
//
// Strip layout (left → right):
//
//   ┌────────────────────────────────────────────────────────────────┐
//   │ TITLE                                                          │
//   │ ┌────scope + LED────┐ [k1][k2] ┌──ADSR──┐ ┌──PITCH──┐ [▶][BAKE]│
//   └────────────────────────────────────────────────────────────────┘
//
// The `role` property picks which two macro knobs appear (see help).

import QtQuick
import QtQuick.Layouts

RetroPanel {
    id: root

    property var instrument: null
    property string role: "kick"        // "kick" | "hat" | "lead" | "bass"
    property bool triggered: false
    property color accent: Retro.amber

    signal previewRequested
    signal bakeRequested

    titleColor: accent
    activeLeds: instrument ? Math.min(ledCount, instrument.activeVoices + 1) : 0

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
        if (role === "kick") return 36
        if (role === "bass") return 43
        return 60
    }

    readonly property var _adsrPoints: {
        if (!instrument) return [[0, 0], [1, 0]]
        var a = instrument.attack, d = instrument.decay
        var s = instrument.sustain, r = instrument.release
        var total = Math.max(0.001, a + d + 0.4 + r)
        return [
            [0, 0],
            [a / total, 1],
            [(a + d) / total, s],
            [(a + d + 0.4) / total, s],
            [1, 0]
        ]
    }
    readonly property var _pitchPoints: {
        if (!instrument) return [[0, 0.5], [1, 0.5]]
        var ps = instrument.pitchStart, pe = instrument.pitchEnd
        var pt = instrument.pitchTime
        function n(v) { return Math.max(0, Math.min(1, 0.5 + v / 48.0)) }
        var xT = Math.max(0.02, Math.min(0.95, pt / 1.0))
        return [[0, n(ps)], [xT, n(pe)], [1, n(pe)]]
    }

    Component.onCompleted: _refreshScope()

    RowLayout {
        anchors.fill: parent.body
        spacing: 10

        // Scope + LED column
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 220
            spacing: 3
            MiniScope {
                Layout.fillWidth: true
                Layout.fillHeight: true
                samples: root._scopeSamples
                traceColor: root.accent
                traceDim: Qt.darker(root.accent, 2.2)
                trigger: root.triggered
            }
            LEDBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                count: 16
                active: root.instrument
                        ? (root.triggered ? 14 : Math.min(14, 2 + root.instrument.activeVoices * 4))
                        : 0
                colorOn: root.accent
            }
        }

        // Macro knobs
        RowLayout {
            Layout.fillHeight: true
            spacing: 6

            // KICK — TUNE + DECAY
            RetroKnob {
                visible: root.role === "kick"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchEnd : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchEnd = v }
            }
            RetroKnob {
                visible: root.role === "kick"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "DECAY"
                from: 0; to: 1; steps: 32
                value: root.instrument ? root.instrument.decay : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.decay = v }
            }

            // HAT — NOISE + RELEASE
            RetroKnob {
                visible: root.role === "hat"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "NOISE"
                from: 0; to: 1; steps: 32
                value: root.instrument ? root.instrument.sustain : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.sustain = v }
            }
            RetroKnob {
                visible: root.role === "hat"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "RELEASE"
                from: 0; to: 0.6; steps: 30
                value: root.instrument ? root.instrument.release : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.release = v }
            }

            // LEAD — TUNE + LFO
            RetroKnob {
                visible: root.role === "lead"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchStart : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchStart = v }
            }
            RetroKnob {
                visible: root.role === "lead"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
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

            // BASS — TUNE + GLIDE
            RetroKnob {
                visible: root.role === "bass"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchEnd : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchEnd = v }
            }
            RetroKnob {
                visible: root.role === "bass"
                Layout.preferredWidth: 56; Layout.preferredHeight: 64
                label: "GLIDE"
                from: 0; to: 0.4; steps: 32
                value: root.instrument ? root.instrument.pitchTime : 0
                accent: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchTime = v }
            }
        }

        StepGraph {
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            label: "ADSR"
            points: root._adsrPoints
        }
        StepGraph {
            Layout.fillHeight: true
            Layout.preferredWidth: 170
            label: "PITCH"
            points: root._pitchPoints
            traceColor: Retro.teal
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 60
            spacing: 4
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: "transparent"
                border.width: 1
                border.color: Retro.bevelHi
                Text {
                    anchors.centerIn: parent
                    text: "▶ PREVIEW"
                    color: Retro.amber
                    font.family: Retro.mono
                    font.pixelSize: Retro.fsLabel
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewRequested()
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
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
            Item { Layout.fillHeight: true }
        }
    }
}
