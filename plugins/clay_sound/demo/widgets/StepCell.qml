// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// One tracker cell: beveled rect + note label + state colouring.
//
// States drive the visuals so the parent just flips flags:
//   active      — a note is set
//   playhead    — this is the current playing step
//   trailStrong — one step behind playhead
//   trailWeak   — two steps behind playhead
//   cursor      — vim/mouse cursor is on this cell
//   beat        — step % 4 === 0 (heavier border)
//   bar         — step % 16 === 0 (thicker border)

import QtQuick

Rectangle {
    id: root

    property string label: "---"
    property bool   active:      false
    property bool   playhead:    false
    property bool   trailStrong: false
    property bool   trailWeak:   false
    property bool   cursor:      false
    property bool   beat:        false
    property bool   bar:         false

    implicitWidth: 42
    implicitHeight: 22
    radius: 2

    color: {
        if (playhead)    return Retro.pink
        if (trailStrong) return Retro.pinkDim
        if (trailWeak)   return "#3a1a26"
        if (active)      return Retro.teal
        if (beat)        return "#19213a"
        return "#0f1424"
    }

    border.width: bar ? 2 : 1
    border.color: cursor ? Retro.cyan
                : (bar ? Retro.bevelHi
                       : (beat ? "#2b3452" : "#121a2c"))

    // Inner bevel (top-left highlight)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.active || root.playhead ? "#ffffff" : "#2a3660"
        opacity: 0.18
    }
    // Inner bevel (bottom-right shadow)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#000000"
        opacity: 0.3
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.active || root.playhead ? "#ffffff"
                                            : (root.trailStrong ? "#d9d9d9"
                                                                : Retro.txtDark)
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: root.active || root.playhead
    }
}
