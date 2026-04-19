// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Clayground.Sound Studio — retro tracker + 4-slot sample bank
// @tags Audio, Sound, Music, Studio, Tracker
// @category Plugin Demos
//
// Self-contained demo. All retro-styled UI widgets live under ./widgets
// so this whole directory can be lifted into its own repo later.

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

    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Vim-mode flag (wired to RetroToggle in the header). When true,
    // the keyboard handler dispatches into the vim state machine below.
    property bool vimMode: false
    // Sub-mode within vimMode: "normal" | "insert" | "append" | "replace" | "jump" | "focus"
    property string vimSubmode: "normal"
    onVimModeChanged: if (!vimMode) { vimSubmode = "normal"; _jumpPrefix = ""; vimFocus = "" }

    // Accumulated keystrokes while in jump mode (max 2 chars).
    property string _jumpPrefix: ""
    // While in "focus" submode, identifies the focused control.
    // Format: "p1:<slotIdx>" | "vol:<slotIdx>" | "bpm" | "length"
    property string vimFocus: ""

    // Bake parameters mirror what the SlotPanel Repeater model carries —
    // exposed at root so jump actions can bake without going through
    // the panel's signal handler.
    readonly property var _slotBakeParams: [
        [36, 0.5, 0.9],
        [60, 0.2, 0.7],
        [60, 0.4, 0.9],
        [43, 0.4, 0.9]
    ]

    // Jump label → action callback. Labels are 2-char combos drawn from
    // the home-row letters so any keyboard layout types them comfortably:
    //   j{a,s,d,f}     jump cursor to tracker row N (col 0)
    //   l{a,s,d}       apply cartridge preset (FROG / COLUMN / MAMPFER)
    //   a{h,j,k,l}     transport: PLAY / STOP / CLEAR / LOOP
    //   s{h,j,k,l}     focus slot N primary knob (TUNE / NOISE)
    //   f{h,j,k,l}     focus slot N VOL
    //   g{h,j,k,l}     toggle slot N PREVIEW loop
    //   k{a,s,d,f}     bake slot N
    //   ha             focus BPM (j/k step ±5)
    //   hs             focus LENGTH (j/k cycle 8/16/32)
    property var _jumpActions: ({})

    function _buildJumpActions() {
        var a = {}
        // Tracker row jumps — cursor goes to (row, 0).
        a["ja"] = function() { tracker.cursorRow = 0; tracker.cursorCol = 0 }
        a["js"] = function() { tracker.cursorRow = 1; tracker.cursorCol = 0 }
        a["jd"] = function() { tracker.cursorRow = 2; tracker.cursorCol = 0 }
        a["jf"] = function() { tracker.cursorRow = 3; tracker.cursorCol = 0 }
        // Cartridges
        a["la"] = function() { tracker.applyPreset("frog");    statusText.text = "preset: frog" }
        a["ls"] = function() { tracker.applyPreset("column");  statusText.text = "preset: column" }
        a["ld"] = function() { tracker.applyPreset("mampfer"); statusText.text = "preset: mampfer" }
        // Transport
        a["ah"] = function() {
            if (tracker.playing) { tracker.playing = false; tracker.step = -1 }
            else                 { tracker.step = -1; tracker.playing = true }
        }
        a["aj"] = function() { tracker.playing = false; tracker.step = -1 }
        a["ak"] = function() { tracker.clearAll() }
        a["al"] = function() { tracker.loop = !tracker.loop }
        // Slot primary knob → focus
        a["sh"] = function() { _enterFocus("p1:0") }
        a["sj"] = function() { _enterFocus("p1:1") }
        a["sk"] = function() { _enterFocus("p1:2") }
        a["sl"] = function() { _enterFocus("p1:3") }
        // Slot secondary knob → focus (DECAY / RELEASE / LFO / GLIDE)
        a["dh"] = function() { _enterFocus("p2:0") }
        a["dj"] = function() { _enterFocus("p2:1") }
        a["dk"] = function() { _enterFocus("p2:2") }
        a["dl"] = function() { _enterFocus("p2:3") }
        // Slot VOL → focus
        a["fh"] = function() { _enterFocus("vol:0") }
        a["fj"] = function() { _enterFocus("vol:1") }
        a["fk"] = function() { _enterFocus("vol:2") }
        a["fl"] = function() { _enterFocus("vol:3") }
        // Slot PREVIEW → toggle
        a["gh"] = function() { var sp = slotRepeater.itemAt(0); if (sp) sp.previewing = !sp.previewing }
        a["gj"] = function() { var sp = slotRepeater.itemAt(1); if (sp) sp.previewing = !sp.previewing }
        a["gk"] = function() { var sp = slotRepeater.itemAt(2); if (sp) sp.previewing = !sp.previewing }
        a["gl"] = function() { var sp = slotRepeater.itemAt(3); if (sp) sp.previewing = !sp.previewing }
        // Slot BAKE
        a["ka"] = function() { _bakeSlot(0) }
        a["ks"] = function() { _bakeSlot(1) }
        a["kd"] = function() { _bakeSlot(2) }
        a["kf"] = function() { _bakeSlot(3) }
        // Tracker BPM / LENGTH → focus
        a["ha"] = function() { _enterFocus("bpm") }
        a["hs"] = function() { _enterFocus("length") }
        _jumpActions = a
    }
    Component.onCompleted: _buildJumpActions()

    function _bakeSlot(i) {
        var sp = slotRepeater.itemAt(i)
        if (sp) sp.previewing = false
        var p = _bankSlots[i].bake(_slotBakeParams[i][0],
                                   _slotBakeParams[i][1],
                                   _slotBakeParams[i][2])
        statusText.text = p.length ? "Baked S" + (i + 1) + " → " + p : "Bake failed"
    }

    function _enterFocus(key) { vimFocus = key; vimSubmode = "focus" }
    function _exitFocus()     { vimFocus = ""; vimSubmode = "normal" }
    function _adjustFocused(delta) {
        if (vimFocus.indexOf("p1:") === 0) {
            var i = parseInt(vimFocus.split(":")[1])
            var slot = _bankSlots[i]
            var role = ["kick", "hat", "lead", "bass"][i]
            if (role === "kick" || role === "bass") {
                slot.pitchEnd = Math.max(-24, Math.min(24, slot.pitchEnd + delta))
            } else if (role === "lead") {
                var v = Math.max(-24, Math.min(24, slot.pitchStart + delta))
                slot.pitchStart = v
                slot.pitchEnd = v
                if (slot.pitchTime <= 0) slot.pitchTime = 0.01
            } else if (role === "hat") {
                slot.sustain = Math.max(0, Math.min(1, slot.sustain + delta * 0.05))
            }
        } else if (vimFocus.indexOf("p2:") === 0) {
            var i2 = parseInt(vimFocus.split(":")[1])
            var slot2 = _bankSlots[i2]
            var role2 = ["kick", "hat", "lead", "bass"][i2]
            if (role2 === "kick") {
                slot2.decay = Math.max(0, Math.min(1, slot2.decay + delta * 0.05))
            } else if (role2 === "hat") {
                slot2.release = Math.max(0, Math.min(0.6, slot2.release + delta * 0.03))
            } else if (role2 === "lead") {
                var lv = Math.max(0, Math.min(4, slot2.lfoDepth + delta * 0.2))
                slot2.lfoDepth = lv
                slot2.lfoRate = 5
                slot2.lfoTarget = lv > 0 ? "pitch" : "none"
            } else if (role2 === "bass") {
                slot2.pitchTime = Math.max(0, Math.min(0.4, slot2.pitchTime + delta * 0.02))
            }
        } else if (vimFocus.indexOf("vol:") === 0) {
            var idx = parseInt(vimFocus.split(":")[1])
            _setSlotLevel(idx, Math.max(0, Math.min(1, _slotLevels[idx] + delta * 0.05)))
        } else if (vimFocus === "bpm") {
            tracker.bpm = Math.max(60, Math.min(220, tracker.bpm + delta * 5))
        } else if (vimFocus === "length") {
            // delta = +1 cycles up (8 → 16 → 32), -1 cycles down
            var sizes = [8, 16, 32]
            var ci = sizes.indexOf(tracker.stepCount)
            if (ci < 0) ci = 1
            ci = Math.max(0, Math.min(sizes.length - 1, ci + (delta > 0 ? 1 : -1)))
            tracker.stepCount = sizes[ci]
        }
    }

    function _enterJump() { vimSubmode = "jump"; _jumpPrefix = "" }
    function _exitJump()  { vimSubmode = "normal"; _jumpPrefix = "" }
    function _processJumpKey(text) {
        if (text.length !== 1) return false
        var next = _jumpPrefix + text
        // Check if any label starts with `next`. If none, abort.
        var anyMatch = false
        for (var k in _jumpActions) { if (k.indexOf(next) === 0) { anyMatch = true; break } }
        if (!anyMatch) { _exitJump(); return true }
        if (next.length === 2 && _jumpActions[next]) {
            _jumpActions[next]()
            _jumpPrefix = ""
            // Only fall back to normal if the action didn't switch us
            // into another mode (e.g. _enterFocus → "focus").
            if (vimSubmode === "jump") vimSubmode = "normal"
            return true
        }
        _jumpPrefix = next
        return true
    }

    // First palette index that the leftmost note key ('a') maps to.
    // The 10 note keys (`asdfghjkl{`) cover [noteBaseIdx ... noteBaseIdx+9].
    // ',' / '.' shift this base by one pentatonic octave (5 notes).
    property int noteBaseIdx: 6     // C3 by default
    readonly property var _noteKeyChars: ["a", "s", "d", "f", "g", "h", "j", "k", "l", "{"]

    function _noteKeyIndex(text) {
        var i = root._noteKeyChars.indexOf(text)
        if (i >= 0) return i
        if (text === ";") return 9      // QWERTY fallback for the 10th slot
        return -1
    }
    function _shiftBaseOctave(delta) {
        var maxBase = tracker.palette.length - 10
        root.noteBaseIdx = Math.max(1, Math.min(maxBase, root.noteBaseIdx + delta))
    }
    function _flashNote(palIdx) {
        notePosOverlay.show(palIdx)
    }
    function _setCellAndMaybeAdvance(palIdx, advance) {
        if (palIdx < 1 || palIdx >= tracker.palette.length) return
        tracker.cellSet(tracker.cursorRow, tracker.cursorCol, palIdx)
        tracker.presetName = "(user)"
        root._flashNote(palIdx)
        // Audition the note when the tracker is idle so the user hears
        // what they entered. While the tracker plays, the stepTimer will
        // fire it on its own — we don't double up.
        if (!tracker.playing) {
            var midi = tracker.palette[palIdx]
            if (midi >= 0)
                root._bankSlots[tracker.cursorRow].triggerNote(midi, 0.85, 0.25)
        }
        if (advance)
            tracker.cursorCol = (tracker.cursorCol + 1) % tracker.stepCount
    }
    function _clearCurrent() {
        tracker.cellClear(tracker.cursorRow, tracker.cursorCol)
        tracker.presetName = "(user)"
    }

    function _handleVimKey(ev) {
        if (root.vimSubmode === "normal")  return root._vimNormal(ev)
        if (root.vimSubmode === "insert")  return root._vimInsert(ev)
        if (root.vimSubmode === "append")  return root._vimAppend(ev)
        if (root.vimSubmode === "replace") return root._vimReplace(ev)
        if (root.vimSubmode === "jump")    return root._vimJump(ev)
        if (root.vimSubmode === "focus")   return root._vimFocusMode(ev)
    }
    function _vimFocusMode(ev) {
        if (ev.key === Qt.Key_Escape) { root._exitFocus(); ev.accepted = true; return }
        if (ev.key === Qt.Key_F)      { root._enterJump(); ev.accepted = true; return }
        var step = (ev.modifiers & Qt.ShiftModifier) ? 5 : 1
        if (ev.key === Qt.Key_J) { root._adjustFocused(-step); ev.accepted = true; return }
        if (ev.key === Qt.Key_K) { root._adjustFocused( step); ev.accepted = true; return }
    }
    function _vimNormal(ev) {
        if (ev.key === Qt.Key_H) { tracker.moveCursor(0, -1); ev.accepted = true; return }
        if (ev.key === Qt.Key_L) { tracker.moveCursor(0,  1); ev.accepted = true; return }
        if (ev.key === Qt.Key_J) { tracker.moveCursor(1,  0); ev.accepted = true; return }
        if (ev.key === Qt.Key_K) { tracker.moveCursor(-1, 0); ev.accepted = true; return }
        if (ev.key === Qt.Key_I) { root.vimSubmode = "insert";  ev.accepted = true; return }
        if (ev.key === Qt.Key_A) { root.vimSubmode = "append";  ev.accepted = true; return }
        if (ev.key === Qt.Key_R) { root.vimSubmode = "replace"; ev.accepted = true; return }
        if (ev.key === Qt.Key_F) { root._enterJump(); ev.accepted = true; return }
        if (ev.key === Qt.Key_U) { tracker.undo(); ev.accepted = true; return }
        if (ev.key === Qt.Key_X) { root._clearCurrent(); ev.accepted = true; return }
        // <Space> toggles play/stop in normal mode (DAW convention).
        if (ev.key === Qt.Key_Space) {
            if (tracker.playing) { tracker.playing = false; tracker.step = -1 }
            else                 { tracker.step = -1; tracker.playing = true }
            ev.accepted = true; return
        }
        if (ev.text === ",") { root._shiftBaseOctave(-5); ev.accepted = true; return }
        if (ev.text === ".") { root._shiftBaseOctave( 5); ev.accepted = true; return }
    }
    function _vimJump(ev) {
        if (ev.key === Qt.Key_Escape) { root._exitJump(); ev.accepted = true; return }
        if (ev.text && ev.text.length === 1) {
            if (root._processJumpKey(ev.text)) { ev.accepted = true; return }
        }
    }
    function _vimInsert(ev) {
        if (ev.key === Qt.Key_Escape)    { root.vimSubmode = "normal"; ev.accepted = true; return }
        if (ev.key === Qt.Key_Space)     {
            tracker.cursorCol = (tracker.cursorCol + 1) % tracker.stepCount
            ev.accepted = true; return
        }
        if (ev.key === Qt.Key_Backspace) { root._clearCurrent(); ev.accepted = true; return }
        if (ev.text === ",") { root._shiftBaseOctave(-5); ev.accepted = true; return }
        if (ev.text === ".") { root._shiftBaseOctave( 5); ev.accepted = true; return }
        var ni = root._noteKeyIndex(ev.text)
        if (ni >= 0) {
            root._setCellAndMaybeAdvance(root.noteBaseIdx + ni, false)
            ev.accepted = true
        }
    }
    function _vimAppend(ev) {
        if (ev.key === Qt.Key_Escape)    { root.vimSubmode = "normal"; ev.accepted = true; return }
        if (ev.key === Qt.Key_Space)     {
            tracker.cursorCol = (tracker.cursorCol + 1) % tracker.stepCount
            ev.accepted = true; return
        }
        if (ev.key === Qt.Key_Backspace) {
            root._clearCurrent()
            tracker.cursorCol = (tracker.cursorCol - 1 + tracker.stepCount) % tracker.stepCount
            ev.accepted = true; return
        }
        if (ev.text === ",") { root._shiftBaseOctave(-5); ev.accepted = true; return }
        if (ev.text === ".") { root._shiftBaseOctave( 5); ev.accepted = true; return }
        var ni = root._noteKeyIndex(ev.text)
        if (ni >= 0) {
            root._setCellAndMaybeAdvance(root.noteBaseIdx + ni, true)
            ev.accepted = true
        }
    }
    function _vimReplace(ev) {
        if (ev.key === Qt.Key_Escape) { root.vimSubmode = "normal"; ev.accepted = true; return }
        var ni = root._noteKeyIndex(ev.text)
        if (ni >= 0)
            root._setCellAndMaybeAdvance(root.noteBaseIdx + ni, false)
        root.vimSubmode = "normal"
        ev.accepted = true
    }

    // Compact 2-letter jump label. Visible only while in jump mode,
    // dims labels whose code doesn't match the current prefix.
    component JumpLabel : Rectangle {
        property string code: ""
        visible: root.vimSubmode === "jump"
        opacity: (root._jumpPrefix === "" || code.indexOf(root._jumpPrefix) === 0) ? 1.0 : 0.25
        z: 1000
        width: 22
        height: 14
        radius: 2
        color: W.Retro.amber
        border.color: W.Retro.bevelHi
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: parent.code
            color: "#0a0f1a"
            font.family: W.Retro.mono
            font.pixelSize: W.Retro.fsLabel
            font.bold: true
        }
    }

    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_F1) {
            helpOverlay.open = !helpOverlay.open
            ev.accepted = true
            return
        }
        if (ev.key === Qt.Key_F12) {
            root.vimMode = !root.vimMode
            ev.accepted = true
            return
        }
        if (ev.key === Qt.Key_Escape && helpOverlay.open) {
            helpOverlay.open = false
            ev.accepted = true
            return
        }
        if (root.vimMode)
            root._handleVimKey(ev)
    }

    // --- Sample Bank (4 slots, editable live) ------------------------
    // Each slot IS a SynthInstrument — editing its properties while the
    // tracker loops means the next trigger uses the new patch. The
    // effective volume is master × per-slot level (see _slotLevels).
    property var _slotLevels: [0.85, 0.70, 0.85, 0.85]

    SynthInstrument {
        id: slot0
        waveform: "sawtooth"
        attack: 0.002; decay: 0.15; sustain: 0.0; release: 0.05
        pitchStart: 12; pitchEnd: -4; pitchTime: 0.12
        volume: volumeSlider.value * root._slotLevels[0]
    }
    SynthInstrument {
        id: slot1
        waveform: "noise"
        attack: 0.002; decay: 0.08; sustain: 0.0; release: 0.05
        pitchStart: 0; pitchEnd: 0; pitchTime: 0
        volume: volumeSlider.value * root._slotLevels[1]
    }
    SynthInstrument {
        id: slot2
        waveform: "square"
        attack: 0.003; decay: 0.06; sustain: 0.45; release: 0.1
        pitchStart: 0; pitchEnd: 0; pitchTime: 0
        volume: volumeSlider.value * root._slotLevels[2]
    }
    SynthInstrument {
        id: slot3
        waveform: "triangle"
        attack: 0.005; decay: 0.12; sustain: 0.55; release: 0.18
        pitchStart: 0; pitchEnd: 0; pitchTime: 0
        volume: volumeSlider.value * root._slotLevels[3]
    }
    property var _bankSlots: [slot0, slot1, slot2, slot3]

    function _setSlotLevel(i, v) {
        var arr = root._slotLevels.slice()
        arr[i] = v
        root._slotLevels = arr
    }

    // --- Header: master volume + vim toggle + help ------------------
    Row {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16

        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "MASTER"
                color: W.Retro.txtDim
                font.family: W.Retro.mono
                font.pixelSize: W.Retro.fsLabel
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Slider {
                id: volumeSlider
                width: 200
                from: 0; to: 1; value: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Math.round(volumeSlider.value * 100) + "%"
                color: W.Retro.teal
                font.family: W.Retro.mono
                font.pixelSize: W.Retro.fsValue
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        W.RetroToggle {
            width: 130; height: 28
            leftLabel: "MOUSE"; rightLabel: "VIM"
            checked: root.vimMode
            onToggled: (v) => root.vimMode = v
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 32; height: 28
            color: "transparent"
            border.color: W.Retro.bevelHi
            border.width: 1
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: "?"
                color: W.Retro.teal
                font.family: W.Retro.mono
                font.pixelSize: W.Retro.fsHeader
                font.bold: true
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: helpOverlay.open = true
            }
        }
    }

    // --- Main content ------------------------------------------------
    ColumnLayout {
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.bottom: statusText.top
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 6

        // ------- Top title bar --------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: W.Retro.panel
            border.color: W.Retro.bevelHi
            border.width: 1
            radius: 2
            // Inner bevel
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: "transparent"
                border.color: W.Retro.bevelLo
                border.width: 1
                radius: 1
            }
            // Left LED group
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 4
                Repeater {
                    model: [W.Retro.red, W.Retro.green, W.Retro.cyan]
                    Rectangle {
                        width: 8; height: 8; radius: 1
                        color: modelData
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2; height: 2
                            color: "#ffffff"
                            opacity: 0.8
                        }
                    }
                }
            }
            // Title
            Text {
                anchors.centerIn: parent
                text: "CLAYGROUND.SOUND STUDIO"
                color: W.Retro.teal
                font.family: W.Retro.mono
                font.pixelSize: W.Retro.fsTitle
                font.bold: true
            }
            // Scanline decoration between title and right LEDs
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: rightLeds.left
                anchors.rightMargin: 8
                spacing: 2
                Repeater {
                    model: 32
                    Rectangle {
                        width: 2; height: 4
                        color: index % 2 ? W.Retro.tealDim : W.Retro.bevelLo
                    }
                }
            }
            // Right LED group
            Row {
                id: rightLeds
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10
                spacing: 4
                Repeater {
                    model: [W.Retro.cyan, W.Retro.red, W.Retro.amber]
                    Rectangle {
                        width: 8; height: 8; radius: 1
                        color: modelData
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2; height: 2
                            color: "#ffffff"
                            opacity: 0.8
                        }
                    }
                }
            }
        }

        // ------- Sample Bank (4 slot columns side-by-side) ----
        // One spec drives all four slots — any layout tweak
        // applied inside the Repeater propagates uniformly.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 8

            Repeater {
                id: slotRepeater
                model: [
                    { title: "S1 KICK", role: "kick", inst: slot0,
                      prev: [36, 0.9, 0.3], bake: [36, 0.5, 0.9] },
                    { title: "S2 HAT",  role: "hat",  inst: slot1,
                      prev: [60, 0.7, 0.2], bake: [60, 0.2, 0.7] },
                    { title: "S3 LEAD", role: "lead", inst: slot2,
                      prev: [60, 0.9, 0.3], bake: [60, 0.4, 0.9] },
                    { title: "S4 BASS", role: "bass", inst: slot3,
                      prev: [43, 0.9, 0.3], bake: [43, 0.4, 0.9] }
                ]
                W.SlotPanel {
                    id: sp
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 446
                    JumpLabel {
                        code: "g" + ["h","j","k","l"][index]
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                    }
                    title: modelData.title
                    role: modelData.role
                    accent: W.Retro.amber
                    instrument: modelData.inst
                    triggered: modelData.inst.activeVoices > 0
                    level: root._slotLevels[index]
                    onLevelEdited: (v) => root._setSlotLevel(index, v)
                    // Vim integration — these drive the JumpLabels and
                    // focus halos rendered inside SlotPanel.
                    slotIndex: index
                    jumpPrefix: root._jumpPrefix
                    jumpActive: root.vimSubmode === "jump"
                    focusedControl: root.vimFocus === ("p1:" + index)  ? "p1"
                                  : root.vimFocus === ("p2:" + index)  ? "p2"
                                  : root.vimFocus === ("vol:" + index) ? "vol"
                                  : ""

                    // Re-triggers the preview note while `previewing`
                    // is true, so the user can hear patch edits live.
                    // Interval = note duration + small gap.
                    Timer {
                        interval: Math.max(200, modelData.prev[2] * 1000 + 100)
                        repeat: true
                        running: sp.previewing
                        triggeredOnStart: true
                        onTriggered: modelData.inst.triggerNote(modelData.prev[0],
                                                                 modelData.prev[1],
                                                                 modelData.prev[2])
                    }
                    onPreviewRequested: sp.previewing = !sp.previewing

                    onBakeRequested: {
                        sp.previewing = false
                        var p = modelData.inst.bake(modelData.bake[0],
                                                    modelData.bake[1],
                                                    modelData.bake[2])
                        statusText.text = p.length
                            ? "Baked " + modelData.title + " → " + p
                            : "Bake failed"
                    }
                }
            }
        }

        // ------- Tracker --------------------------------------
        W.RetroPanel {
            id: tracker
            // Match the combined width of 4 slot columns (with
            // inter-slot spacing): 220 × 4 + 8 × 3.
            readonly property int slotW: 220
            readonly property int slotSpacing: 8
            Layout.preferredWidth: slotW * 4 + slotSpacing * 3
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.preferredHeight: 310
            title: "TRACKER · " + tracker.stepCount + " STEPS × " + tracker.trackCount + " TRACKS"
            titleColor: W.Retro.teal
            activeLeds: tracker.playing ? 4 : 1

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
            readonly property int cellHeight: 34
            readonly property int rowLabelWidth: 40
            // Cells expand to fill available tracker width.
            property int  gridAvailWidth: 0
            readonly property int cellWidth:
                Math.max(22, Math.floor((gridAvailWidth - rowLabelWidth) / stepCount))

            property int  step: -1
            property bool playing: false
            property bool loop: true
            property int  bpm: 130
            property string presetName: "(user)"

            // Vim cursor — current row/col under the keyboard cursor.
            property int cursorRow: 0
            property int cursorCol: 0
            function moveCursor(dr, dc) {
                cursorRow = Math.max(0, Math.min(trackCount - 1, cursorRow + dr))
                cursorCol = Math.max(0, Math.min(stepCount - 1, cursorCol + dc))
            }
            // tracks[row] = Array(stepCount) of palette indices (0..N-1)
            property var  tracks: [
                Array(16).fill(0),
                Array(16).fill(0),
                Array(16).fill(0),
                Array(16).fill(0)
            ]

            // Undo stack of {tracks, stepCount, presetName} snapshots.
            // _pushUndo() captures the current state BEFORE a mutating call.
            property var _undoStack: []

            function _pushUndo() {
                var snap = {
                    tracks: tracks.map(function(r) { return r.slice() }),
                    stepCount: stepCount,
                    presetName: presetName
                }
                _undoStack.push(snap)
                if (_undoStack.length > 32) _undoStack.shift()
            }
            function undo() {
                if (_undoStack.length === 0) return
                var snap = _undoStack.pop()
                if (stepCount !== snap.stepCount) stepCount = snap.stepCount
                tracks = snap.tracks
                presetName = snap.presetName
            }

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
                if (cursorCol >= newCount) cursorCol = newCount - 1
            }

            function cellSet(row, idx, paletteIdx) {
                _pushUndo()
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
                _pushUndo()
                var all = []
                for (var i = 0; i < trackCount; ++i) all.push(Array(stepCount).fill(0))
                tracks = all
            }

            function applyPreset(name) {
                _pushUndo()
                // Reset optional FX so presets start from a known baseline.
                for (var si = 0; si < root._bankSlots.length; ++si) {
                    var s = root._bankSlots[si]
                    s.lfoTarget = "none"; s.lfoRate = 0; s.lfoDepth = 0
                }
                if (name === "frog") {
                    // Frogger-inspired: upbeat, hoppy, cheerful pond-hop vibe.
                    bpm = 132
                    presetName = "frog"
                    stepCount = 16
                    // Slot 0 — bright square hop kick
                    slot0.waveform = "square"
                    slot0.attack = 0.001; slot0.decay = 0.08; slot0.sustain = 0.0; slot0.release = 0.04
                    slot0.pitchStart = 10; slot0.pitchEnd = 0; slot0.pitchTime = 0.05
                    // Slot 1 — clicky noise tick (lily-pad tap)
                    slot1.waveform = "noise"
                    slot1.attack = 0.001; slot1.decay = 0.03; slot1.sustain = 0.0; slot1.release = 0.02
                    slot1.pitchStart = 0; slot1.pitchEnd = 0; slot1.pitchTime = 0
                    // Slot 2 — bouncy triangle lead
                    slot2.waveform = "triangle"
                    slot2.attack = 0.002; slot2.decay = 0.1; slot2.sustain = 0.2; slot2.release = 0.08
                    slot2.pitchStart = 0; slot2.pitchEnd = 0; slot2.pitchTime = 0
                    // Slot 3 — rounded triangle bass
                    slot3.waveform = "triangle"
                    slot3.attack = 0.005; slot3.decay = 0.12; slot3.sustain = 0.3; slot3.release = 0.1
                    slot3.pitchStart = 0; slot3.pitchEnd = 0; slot3.pitchTime = 0
                    // Kick every beat, tap offbeat, leaping C5/G5/C6 melody, hopping bass
                    var fk = Array(16).fill(0); fk[0]=6; fk[4]=6; fk[8]=6; fk[12]=6
                    var fh = Array(16).fill(0); fh[2]=8; fh[6]=8; fh[10]=8; fh[14]=8
                    var fl = Array(16).fill(0)
                    fl[0]=16; fl[2]=19; fl[4]=21; fl[6]=19    // C5 G5 C6 G5
                    fl[8]=17; fl[10]=16; fl[12]=19; fl[14]=16 // Eb5 C5 G5 C5
                    var fb = Array(16).fill(0); fb[0]=1; fb[4]=1; fb[8]=4; fb[12]=4
                    tracks = [fk, fh, fl, fb]
                } else if (name === "column") {
                    // Tetris / Korobeiniki-inspired: driving minor-key march.
                    bpm = 140
                    presetName = "column"
                    stepCount = 16
                    // Slot 0 — punchy square kick
                    slot0.waveform = "square"
                    slot0.attack = 0.001; slot0.decay = 0.10; slot0.sustain = 0.0; slot0.release = 0.05
                    slot0.pitchStart = 14; slot0.pitchEnd = -2; slot0.pitchTime = 0.06
                    // Slot 1 — noise snare
                    slot1.waveform = "noise"
                    slot1.attack = 0.002; slot1.decay = 0.08; slot1.sustain = 0.0; slot1.release = 0.05
                    slot1.pitchStart = 0; slot1.pitchEnd = 0; slot1.pitchTime = 0
                    // Slot 2 — classic square chip lead
                    slot2.waveform = "square"
                    slot2.attack = 0.002; slot2.decay = 0.08; slot2.sustain = 0.35; slot2.release = 0.06
                    slot2.pitchStart = 0; slot2.pitchEnd = 0; slot2.pitchTime = 0
                    // Slot 3 — driving sawtooth bass
                    slot3.waveform = "sawtooth"
                    slot3.attack = 0.002; slot3.decay = 0.08; slot3.sustain = 0.45; slot3.release = 0.05
                    slot3.pitchStart = 0; slot3.pitchEnd = 0; slot3.pitchTime = 0
                    // Stepwise chip-lead on every step, snare on 2 & 4,
                    // driving eighth-note bass walking i → iv → v.
                    var ck = Array(16).fill(0); ck[0]=6; ck[4]=6; ck[8]=6; ck[12]=6
                    var cs = Array(16).fill(0); cs[4]=12; cs[12]=12
                    // G4 C5 Eb5 F5  Eb5 C5 Bb4 C5   Eb5 C5 Bb4 G4  Bb4 C5 Eb5 F5
                    var cl = [13, 16, 17, 18, 17, 16, 15, 16, 17, 16, 15, 13, 15, 16, 17, 18]
                    var cb = Array(16).fill(0)
                    cb[0]=1; cb[2]=1; cb[4]=1; cb[6]=1
                    cb[8]=3; cb[10]=3; cb[12]=4; cb[14]=4
                    tracks = [ck, cs, cl, cb]
                } else if (name === "mampfer") {
                    // Pac-Man-inspired: chase pace, waka-waka ticks, chomping bass.
                    bpm = 150
                    presetName = "mampfer"
                    stepCount = 16
                    // Slot 0 — tight square chomp kick
                    slot0.waveform = "square"
                    slot0.attack = 0.001; slot0.decay = 0.06; slot0.sustain = 0.0; slot0.release = 0.03
                    slot0.pitchStart = 8; slot0.pitchEnd = 0; slot0.pitchTime = 0.03
                    // Slot 1 — rapid noise waka tick
                    slot1.waveform = "noise"
                    slot1.attack = 0.001; slot1.decay = 0.02; slot1.sustain = 0.0; slot1.release = 0.02
                    slot1.pitchStart = 0; slot1.pitchEnd = 0; slot1.pitchTime = 0
                    // Slot 2 — square chase lead
                    slot2.waveform = "square"
                    slot2.attack = 0.001; slot2.decay = 0.06; slot2.sustain = 0.25; slot2.release = 0.04
                    slot2.pitchStart = 0; slot2.pitchEnd = 0; slot2.pitchTime = 0
                    // Slot 3 — bouncy square munch bass
                    slot3.waveform = "square"
                    slot3.attack = 0.001; slot3.decay = 0.08; slot3.sustain = 0.35; slot3.release = 0.05
                    slot3.pitchStart = 0; slot3.pitchEnd = 0; slot3.pitchTime = 0
                    // Kick on every beat, waka tick on every odd step,
                    // descending arcade arpeggio, bouncing C2/Eb2 bass.
                    var pk = Array(16).fill(0); pk[0]=6; pk[4]=6; pk[8]=6; pk[12]=6
                    var pt = Array(16).fill(0)
                    pt[1]=11; pt[3]=11; pt[5]=11; pt[7]=11
                    pt[9]=11; pt[11]=11; pt[13]=11; pt[15]=11
                    // C6 · G5 · Eb5 · C5 ·   Bb5 · F5 · Eb5 · C5
                    var pl = [21, 0, 19, 0, 17, 0, 16, 0, 20, 0, 18, 0, 17, 0, 16, 0]
                    var pb = Array(16).fill(0)
                    pb[0]=1; pb[2]=2; pb[4]=1; pb[6]=2
                    pb[8]=1; pb[10]=2; pb[12]=1; pb[14]=2
                    tracks = [pk, pt, pl, pb]
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

            // Chunky mechanical transport button — visible top
            // highlight + bottom shadow sell the "real key" feel.
            component RetroBtn : Rectangle {
                property string text: ""
                property color  accent: W.Retro.amber
                property bool   on: false
                signal clicked
                implicitWidth: 82; implicitHeight: 34
                color: on ? "#1c2844" : "#141c30"
                border.width: 1
                border.color: on ? accent : W.Retro.bevelHi
                radius: 2
                // Top light band (key cap highlight)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 3
                    color: on ? Qt.lighter(parent.color, 1.5) : W.Retro.panelHi
                    opacity: 0.85
                    radius: 1
                }
                // Bottom dark band (shadow)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 2
                    color: "#000000"
                    opacity: 0.45
                }
                Text {
                    anchors.centerIn: parent
                    text: parent.text
                    color: on ? "#ffffff" : W.Retro.txt
                    font.family: W.Retro.mono
                    font.pixelSize: W.Retro.fsValue
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.clicked()
                }
            }

            // LCD-style digital readout. Click to cycle values
            // from `cycle`, or scroll to step value in `step`.
            component DigitalBox : Rectangle {
                property string label: ""
                property string value: ""
                property color  valueColor: W.Retro.amber
                property var    cycle: []       // optional click cycle
                property real   step: 0         // optional wheel step
                property real   minv: 0
                property real   maxv: 0
                signal valueSelected(var v)
                signal stepRequested(real delta)
                implicitWidth: 108; implicitHeight: 34
                color: "#090d19"
                border.width: 1
                border.color: W.Retro.bevelHi
                radius: 2
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 2
                    color: W.Retro.panelHi
                    opacity: 0.7
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: parent.parent.label + ":"
                        color: W.Retro.txtDim
                        font.family: W.Retro.mono
                        font.pixelSize: W.Retro.fsValue
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: parent.parent.value
                        color: parent.parent.valueColor
                        font.family: W.Retro.mono
                        font.pixelSize: W.Retro.fsHeader
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (ev) => {
                        if (parent.cycle.length > 0) {
                            var cur = parent.cycle.indexOf(parent.value)
                            var next = ev.button === Qt.RightButton
                                ? (cur - 1 + parent.cycle.length) % parent.cycle.length
                                : (cur + 1) % parent.cycle.length
                            parent.valueSelected(parent.cycle[next])
                        }
                    }
                    onWheel: (ev) => {
                        if (parent.step !== 0) {
                            var dir = ev.angleDelta.y > 0 ? 1 : -1
                            parent.stepRequested(dir * parent.step)
                        }
                    }
                }
            }

            Column {
                id: trackerColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 4
                spacing: 8

                // Transport strip — chunky mechanical buttons +
                // digital BPM/LENGTH readouts to the right.
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    spacing: 10

                    Row {
                        spacing: 6
                        RetroBtn {
                            text: "▶ PLAY"
                            accent: W.Retro.green
                            on: tracker.playing
                            onClicked: { tracker.step = -1; tracker.playing = true }
                            JumpLabel {
                                code: "ah"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 2
                            }
                        }
                        RetroBtn {
                            text: "■ STOP"
                            accent: W.Retro.red
                            onClicked: { tracker.playing = false; tracker.step = -1 }
                            JumpLabel {
                                code: "aj"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 2
                            }
                        }
                        RetroBtn {
                            text: "CLEAR"
                            accent: W.Retro.pink
                            onClicked: tracker.clearAll()
                            JumpLabel {
                                code: "ak"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 2
                            }
                        }
                        RetroBtn {
                            text: "LOOP"
                            accent: W.Retro.teal
                            on: tracker.loop
                            onClicked: tracker.loop = !tracker.loop
                            JumpLabel {
                                code: "al"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 2
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 28
                        color: W.Retro.bevelLo
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DigitalBox {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "BPM"
                        value: tracker.bpm.toString()
                        valueColor: W.Retro.amber
                        step: 2
                        onStepRequested: (d) => tracker.bpm =
                            Math.max(60, Math.min(220, tracker.bpm + d))
                        JumpLabel {
                            code: "ha"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                        }
                        Rectangle {
                            visible: root.vimFocus === "bpm"
                            anchors.fill: parent
                            anchors.margins: -3
                            color: "transparent"
                            border.color: W.Retro.cyan
                            border.width: 2
                            radius: 4
                            z: 5
                            SequentialAnimation on opacity {
                                running: root.vimFocus === "bpm"
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.55; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 1.0; to: 0.55; duration: 400; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    DigitalBox {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "LENGTH"
                        value: tracker.stepCount.toString()
                        valueColor: W.Retro.teal
                        cycle: ["8", "16", "32"]
                        onValueSelected: (v) => tracker.stepCount = parseInt(v)
                        JumpLabel {
                            code: "hs"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                        }
                        Rectangle {
                            visible: root.vimFocus === "length"
                            anchors.fill: parent
                            anchors.margins: -3
                            color: "transparent"
                            border.color: W.Retro.cyan
                            border.width: 2
                            radius: 4
                            z: 5
                            SequentialAnimation on opacity {
                                running: root.vimFocus === "length"
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.55; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 1.0; to: 0.55; duration: 400; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }

                // Cartridge preset row
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    spacing: 10
                    W.CartridgeButton {
                        width: 140; height: 28
                        tag: "01"; label: "FROG"
                        selected: tracker.presetName === "frog"
                        onClicked: { tracker.applyPreset("frog"); statusText.text = "preset: frog" }
                        JumpLabel {
                            code: "la"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                        }
                    }
                    W.CartridgeButton {
                        width: 140; height: 28
                        tag: "02"; label: "COLUMN"
                        selected: tracker.presetName === "column"
                        onClicked: { tracker.applyPreset("column"); statusText.text = "preset: column" }
                        JumpLabel {
                            code: "ls"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                        }
                    }
                    W.CartridgeButton {
                        width: 140; height: 28
                        tag: "03"; label: "MAMPFER"
                        selected: tracker.presetName === "mampfer"
                        onClicked: { tracker.applyPreset("mampfer"); statusText.text = "preset: mampfer" }
                        JumpLabel {
                            code: "ld"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "→ " + tracker.presetName
                        color: W.Retro.txtDim
                        font.family: W.Retro.mono
                        font.pixelSize: W.Retro.fsLabel
                    }
                }

                // Grid area: dark inset rectangle with row labels, cells,
                // red beat dividers overlay, and a moving playhead bar.
                Item {
                    id: gridArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: tracker.trackCount * tracker.cellHeight
                    onWidthChanged: tracker.gridAvailWidth = width
                    Component.onCompleted: tracker.gridAvailWidth = width

                    // Dark inset background
                    Rectangle {
                        anchors.fill: parent
                        color: W.Retro.inset
                        border.color: W.Retro.bevelLo
                        border.width: 1
                        radius: 2
                    }

                    Column {
                        anchors.fill: parent
                        spacing: 0
                        Repeater {
                            model: tracker.trackCount
                            Row {
                                readonly property int rowIdx: index
                                spacing: 0
                                Rectangle {
                                    width: tracker.rowLabelWidth
                                    height: tracker.cellHeight
                                    color: W.Retro.panelLo
                                    border.color: W.Retro.bevelLo
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "S" + (rowIdx + 1)
                                        color: W.Retro.teal
                                        font.family: W.Retro.mono
                                        font.bold: true
                                        font.pixelSize: W.Retro.fsValue
                                    }
                                    JumpLabel {
                                        code: "j" + ["a","s","d","f"][rowIdx]
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                    }
                                }
                                Repeater {
                                    model: tracker.stepCount
                                    W.StepCell {
                                        readonly property int  stepIdx: index
                                        readonly property int  paletteIdx: tracker.tracks[parent.rowIdx][stepIdx]
                                        width: tracker.cellWidth
                                        height: tracker.cellHeight
                                        label: tracker.paletteLabels[paletteIdx]
                                        active: paletteIdx > 0
                                        playhead: false
                                        trailStrong: false
                                        trailWeak: false
                                        beat:      (stepIdx % 4) === 0
                                        bar:       false
                                        cursor: root.vimMode
                                                && tracker.cursorRow === parent.rowIdx
                                                && stepIdx === tracker.cursorCol
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
                    }

                    // Red beat dividers — every 4 steps, between cells.
                    Repeater {
                        model: Math.max(0, Math.floor((tracker.stepCount - 1) / 4))
                        Rectangle {
                            x: tracker.rowLabelWidth + (index + 1) * 4 * tracker.cellWidth - 2
                            y: 0
                            width: 5
                            height: gridArea.height
                            color: W.Retro.red
                            opacity: 0.85
                            // Inner white core for a CRT "light pipe" look
                            Rectangle {
                                anchors.centerIn: parent
                                width: 1; height: parent.height
                                color: "#ffffff"; opacity: 0.25
                            }
                        }
                    }

                    // Moving playhead: single vertical bar spanning all rows.
                    Rectangle {
                        visible: tracker.playing && tracker.step >= 0
                        x: tracker.rowLabelWidth + tracker.step * tracker.cellWidth
                        y: 0
                        width: tracker.cellWidth
                        height: gridArea.height
                        color: W.Retro.pink
                        opacity: 0.22
                        border.color: W.Retro.pink
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                    }
                }

                // Brief note-position indicator. Shows the just-entered
                // note's place in the full palette range — fades after
                // ~700ms. Helps the user learn the keyboard layout.
                Item {
                    id: notePosOverlay
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 16
                    opacity: 0
                    visible: opacity > 0.01

                    property int currentIdx: 0

                    function show(palIdx) {
                        currentIdx = palIdx
                        opacity = 1
                        hideTimer.restart()
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Timer {
                        id: hideTimer
                        interval: 700
                        onTriggered: notePosOverlay.opacity = 0
                    }

                    Text {
                        id: noteLabelText
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        text: tracker.paletteLabels[notePosOverlay.currentIdx]
                        color: W.Retro.amber
                        font.family: W.Retro.mono
                        font.pixelSize: W.Retro.fsValue
                        font.bold: true
                    }
                    Row {
                        anchors.left: noteLabelText.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: tracker.palette.length - 1     // skip rest at idx 0
                            Rectangle {
                                width: 6; height: 12
                                radius: 1
                                color: index === (notePosOverlay.currentIdx - 1)
                                       ? W.Retro.amber : W.Retro.bevelLo
                                opacity: index === (notePosOverlay.currentIdx - 1) ? 1.0 : 0.55
                            }
                        }
                    }
                }

                // Bottom status strip: READY lamp + click-hint OR vim mode
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 24
                    color: W.Retro.panelLo
                    border.color: W.Retro.bevelLo
                    border.width: 1
                    radius: 2
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 1
                            color: tracker.playing ? W.Retro.green : W.Retro.greenDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: tracker.playing ? "PLAYING" : "READY"
                            color: W.Retro.green
                            font.family: W.Retro.mono
                            font.pixelSize: W.Retro.fsValue
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.vimMode
                              ? ("-- " + root.vimSubmode.toUpperCase() + " --   "
                                 + "(S" + (tracker.cursorRow + 1) + ", " + (tracker.cursorCol + 1) + ")"
                                 + "   base: " + tracker.paletteLabels[root.noteBaseIdx])
                              : "LEFT CLICK TO EDIT NOTE · RIGHT CLICK TO CLEAR"
                        color: root.vimMode ? W.Retro.cyan : W.Retro.txtDim
                        font.family: W.Retro.mono
                        font.pixelSize: W.Retro.fsLabel
                        font.bold: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        text: "→ " + tracker.presetName.toUpperCase()
                        color: W.Retro.txtDim
                        font.family: W.Retro.mono
                        font.pixelSize: W.Retro.fsLabel
                        font.bold: true
                    }
                }
            }
        }

        // Trailing flex spacer pushes the tracker up against
        // the slot row; any extra vertical space lands here.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
