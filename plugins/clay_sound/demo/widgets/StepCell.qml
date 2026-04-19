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
        if (trailStrong) return Qt.darker(Retro.pink, 1.8)
        if (trailWeak)   return Qt.darker(Retro.pink, 3.5)
        if (active)      return Retro.teal
        if (beat)        return "#1d273f"
        return "#0d1222"
    }

    // Bar (every 16 steps) gets a thicker, brighter border.
    border.width: bar ? 2 : 1
    border.color: cursor ? Retro.cyan
                : (bar ? Retro.tealDim
                       : (beat ? "#35456b" : "#141b30"))

    // Inner bevel (top-left highlight)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.active || root.playhead ? "#ffffff" : "#3a486b"
        opacity: root.active || root.playhead ? 0.35 : 0.22
    }
    // Inner bevel (bottom-right shadow)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#000000"
        opacity: 0.35
    }

    // Subtle white flash on top of playhead fill — CRT-scanline
    // highlight, fades back down so trail cells look settled.
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        opacity: root.playhead ? 0.28 : 0
        radius: 2
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    // Pink glow outline on the live playhead cell only — pops it out
    // from the trail.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        color: "transparent"
        border.color: Retro.pink
        border.width: 2
        radius: 3
        opacity: root.playhead ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.active || root.playhead ? "#ffffff"
                                            : (root.trailStrong ? "#e4e4e4"
                                                                : (root.trailWeak ? "#a49099"
                                                                                  : Retro.txtDark))
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: root.active || root.playhead
    }
}
