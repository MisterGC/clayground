// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SlotPanel — one rack-mount "cartridge column" bound to a live
// SynthInstrument. Designed to be tiled side-by-side in the Studio
// tab: each slot fills its column completely, and internals stack
// richly from top to bottom.
//
// Layout (top → bottom):
//
//   ┌──────────────────────────────────────┐
//   │ TITLE                           · · ·│
//   ├──────────────────────────────────────┤
//   │  ┌──────── SCOPE ───────┐            │
//   │  └──────────────────────┘            │
//   │  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  (LED strip)│
//   │                                      │
//   │   ┌────┐  ┌────┐                     │
//   │   │ k1 │  │ k2 │                     │
//   │   └────┘  └────┘                     │
//   │   ▬▬▬▬    ▬▬▬▬   (per-knob LED meter)│
//   │                                      │
//   │  ┌──────── ADSR ───────┐             │
//   │  └──────────────────────┘            │
//   │                                      │
//   │  ┌──────── PITCH ──────┐             │
//   │  └──────────────────────┘            │
//   │                                      │
//   │  [▶ PREVIEW]  [BAKE]                 │
//   └──────────────────────────────────────┘
//
// The `role` property picks which two macro knobs appear.

import QtQuick
import QtQuick.Layouts

RetroPanel {
    id: root

    property var instrument: null
    property string role: "kick"        // "kick" | "hat" | "lead" | "bass"
    property bool triggered: false
    property color accent: Retro.amber
    // Per-slot level (0..1). The caller multiplies this with master
    // volume when binding the SynthInstrument's `volume` property.
    property real level: 0.85
    // External "is the preview currently looping" state. The button
    // toggles its visual based on this; the caller owns the actual
    // re-trigger Timer, which is why this is driven from outside.
    property bool previewing: false

    // Vim integration — driven from outside.
    property int    slotIndex: 0           // 0..3, used for jump label codes
    property string jumpPrefix: ""         // accumulated jump prefix
    property bool   jumpActive: false      // true while in vim jump mode
    property string focusedControl: ""     // "" | "p1" | "vol"

    signal previewRequested
    signal bakeRequested
    signal levelEdited(real v)

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

    // Inline knob + LED meter sub-layout (the little LED bar under the
    // knob mirrors the value; makes empty space feel instrumented).
    //
    // The column fills its slice of the parent row, so the LED meter
    // can stretch across the full column width while the knob stays
    // square-centered above it.
    component KnobMeter : ColumnLayout {
        id: km
        property string label: ""
        property real from: 0
        property real to: 1
        property int steps: 32
        property real value: 0
        property color accent: Retro.teal
        property color meterColor: Retro.amber
        // True when this knob is the focused control under vim focus mode;
        // shows a pulsing cyan halo behind the knob.
        property bool focused: false
        // Optional jump label for the knob (rendered top-right of knob).
        property string jumpCode: ""
        property string jumpPrefix: ""
        property bool   jumpActive: false
        readonly property real _norm:
            (to === from) ? 0
                          : Math.max(0, Math.min(1, (value - from) / (to - from)))
        signal valueEdited(real v)
        spacing: 3
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredWidth: 84
            Layout.maximumWidth: 110
            Layout.preferredHeight: 84
            // Pulsing focus halo.
            Rectangle {
                visible: km.focused
                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"
                border.color: Retro.cyan
                border.width: 2
                radius: 6
                z: 5
                SequentialAnimation on opacity {
                    running: km.focused
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.55; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.0; to: 0.55; duration: 400; easing.type: Easing.InOutQuad }
                }
            }
            RetroKnob {
                anchors.fill: parent
                label: km.label
                from: km.from; to: km.to; steps: km.steps
                value: km.value
                accent: km.accent
                onValueEdited: (v) => km.valueEdited(v)
            }
            JumpLabel {
                code: km.jumpCode
                activePrefix: km.jumpPrefix
                jumpActive: km.jumpActive && km.jumpCode.length > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 0
            }
        }
        LEDBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 7
            count: 14
            ledHeight: 5
            gap: 1
            active: km._norm * count
            colorOn: km.meterColor
            colorOff: Qt.darker(km.meterColor, 3.2)
        }
    }

    ColumnLayout {
        anchors.fill: parent.body
        spacing: 6

        // --- Scope + LED strip ---------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 108
            spacing: 2
            MiniScope {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                samples: root._scopeSamples
                traceColor: root.accent
                traceDim: Qt.darker(root.accent, 2.2)
                trigger: root.triggered
            }
            LEDBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                count: 20
                active: root.instrument
                        ? (root.triggered ? 18 : Math.min(18, 2 + root.instrument.activeVoices * 5))
                        : 0
                colorOn: root.accent
                colorOff: Qt.darker(root.accent, 3.5)
            }
        }

        // --- Macro knobs row -----------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // KICK — TUNE + DECAY
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "kick"
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchEnd : 0
                meterColor: Retro.red
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchEnd = v }
                focused: root.focusedControl === "p1"
                jumpCode: "s" + ["h","j","k","l"][root.slotIndex]
                jumpPrefix: root.jumpPrefix
                jumpActive: root.jumpActive
            }
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "kick"
                label: "DECAY"
                from: 0; to: 1; steps: 32
                value: root.instrument ? root.instrument.decay : 0
                meterColor: Retro.teal
                onValueEdited: (v) => { if (root.instrument) root.instrument.decay = v }
            }

            // HAT — NOISE + RELEASE
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "hat"
                label: "NOISE"
                from: 0; to: 1; steps: 32
                value: root.instrument ? root.instrument.sustain : 0
                meterColor: Retro.amber
                onValueEdited: (v) => { if (root.instrument) root.instrument.sustain = v }
                focused: root.focusedControl === "p1"
                jumpCode: "s" + ["h","j","k","l"][root.slotIndex]
                jumpPrefix: root.jumpPrefix
                jumpActive: root.jumpActive
            }
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "hat"
                label: "RELEASE"
                from: 0; to: 0.6; steps: 30
                value: root.instrument ? root.instrument.release : 0
                meterColor: Retro.amber
                onValueEdited: (v) => { if (root.instrument) root.instrument.release = v }
            }

            // LEAD — TUNE + LFO
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "lead"
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchStart : 0
                meterColor: Retro.amber
                // The engine skips the pitch envelope when pitchTime==0,
                // so a constant transpose needs both endpoints equal AND
                // a tiny non-zero time to activate the envelope path.
                onValueEdited: (v) => {
                    if (root.instrument) {
                        root.instrument.pitchStart = v
                        root.instrument.pitchEnd = v
                        if (root.instrument.pitchTime <= 0)
                            root.instrument.pitchTime = 0.01
                    }
                }
                focused: root.focusedControl === "p1"
                jumpCode: "s" + ["h","j","k","l"][root.slotIndex]
                jumpPrefix: root.jumpPrefix
                jumpActive: root.jumpActive
            }
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "lead"
                label: "LFO"
                from: 0; to: 4; steps: 32
                value: root.instrument ? root.instrument.lfoDepth : 0
                meterColor: Retro.amber
                onValueEdited: (v) => {
                    if (root.instrument) {
                        root.instrument.lfoDepth = v
                        root.instrument.lfoRate = 5
                        root.instrument.lfoTarget = v > 0 ? "pitch" : "none"
                    }
                }
            }

            // BASS — TUNE + GLIDE
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "bass"
                label: "TUNE"
                from: -24; to: 24; steps: 48
                value: root.instrument ? root.instrument.pitchEnd : 0
                meterColor: Retro.red
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchEnd = v }
                focused: root.focusedControl === "p1"
                jumpCode: "s" + ["h","j","k","l"][root.slotIndex]
                jumpPrefix: root.jumpPrefix
                jumpActive: root.jumpActive
            }
            KnobMeter {
                Layout.fillWidth: true
                visible: root.role === "bass"
                label: "GLIDE"
                from: 0; to: 0.4; steps: 32
                value: root.instrument ? root.instrument.pitchTime : 0
                meterColor: Retro.red
                onValueEdited: (v) => { if (root.instrument) root.instrument.pitchTime = v }
            }

        }

        // --- VOL strip ------------------------------------------------
        // Compact horizontal level meter; click or drag to set.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 6
            Text {
                Layout.preferredWidth: 28
                text: "VOL"
                color: Retro.txtDim
                font.family: Retro.mono
                font.pixelSize: Retro.fsLabel
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                LEDBar {
                    anchors.fill: parent
                    count: 20
                    active: root.level * count
                    colorOn: Retro.green
                    colorOff: Qt.darker(Retro.green, 3.5)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function _apply(x) {
                        var v = Math.max(0, Math.min(1, x / Math.max(1, width)))
                        root.levelEdited(v)
                    }
                    onPressed: (ev) => _apply(ev.x)
                    onPositionChanged: (ev) => { if (pressed) _apply(ev.x) }
                }
                // Pulsing focus halo when VOL is the focused control.
                Rectangle {
                    visible: root.focusedControl === "vol"
                    anchors.fill: parent
                    anchors.margins: -3
                    color: "transparent"
                    border.color: Retro.cyan
                    border.width: 2
                    radius: 3
                    z: 5
                    SequentialAnimation on opacity {
                        running: root.focusedControl === "vol"
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.55; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.0; to: 0.55; duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
                JumpLabel {
                    code: "f" + ["h","j","k","l"][root.slotIndex]
                    activePrefix: root.jumpPrefix
                    jumpActive: root.jumpActive
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                Layout.preferredWidth: 34
                text: Math.round(root.level * 100) + "%"
                color: Retro.green
                font.family: Retro.mono
                font.pixelSize: Retro.fsLabel
                font.bold: true
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        // --- ADSR graph ----------------------------------------------
        StepGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            label: "ADSR"
            points: root._adsrPoints
        }

        // --- PITCH graph ---------------------------------------------
        StepGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            label: "PITCH"
            points: root._pitchPoints
            traceColor: Retro.teal
        }

        // Absorb remaining vertical space; content stays top-aligned.
        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        // --- Action row ----------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                color: root.previewing ? Qt.darker(Retro.green, 1.8) : "transparent"
                border.width: 1
                border.color: root.previewing ? Retro.green : Retro.bevelHi
                radius: 2
                Text {
                    anchors.centerIn: parent
                    text: root.previewing ? "■ STOP" : "▶ PREVIEW"
                    color: root.previewing ? "#ffffff" : Retro.amber
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
                Layout.preferredHeight: 22
                color: "transparent"
                border.width: 1
                border.color: Retro.bevelHi
                radius: 2
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
                JumpLabel {
                    code: "k" + ["a","s","d","f"][root.slotIndex]
                    activePrefix: root.jumpPrefix
                    jumpActive: root.jumpActive
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 2
                }
            }
        }
    }
}
