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

    implicitWidth: 46
    implicitHeight: 30
    radius: 1

    // Every cell has a clear recessed "key" look whether active or not.
    color: {
        if (playhead)    return Retro.pink
        if (trailStrong) return Qt.darker(Retro.pink, 1.8)
        if (trailWeak)   return Qt.darker(Retro.pink, 3.5)
        if (active)      return Retro.teal
        return beat ? "#1a2742" : "#0f1628"
    }

    border.width: 1
    border.color: cursor ? Retro.cyan
                : (active ? Qt.lighter(Retro.teal, 1.3)
                          : (beat ? "#2a3656" : "#1b2540"))

    // Always-visible inner top highlight (the "key cap" edge).
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: 1
        color: root.active || root.playhead ? "#ffffff" : "#4a5a80"
        opacity: root.active || root.playhead ? 0.45 : 0.3
    }
    // Always-visible inner bottom shadow.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: 1
        color: "#000000"
        opacity: 0.45
    }

    // White flash on playhead fill.
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        opacity: root.playhead ? 0.28 : 0
        radius: root.radius
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    // Pink glow outline on the live playhead cell only.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        color: "transparent"
        border.color: Retro.pink
        border.width: 2
        radius: 2
        opacity: root.playhead ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.active || root.playhead ? "#ffffff"
                                            : (root.trailStrong ? "#e4e4e4"
                                                                : (root.trailWeak ? "#a49099"
                                                                                  : "#7a8aaf"))
        font.family: Retro.mono
        font.pixelSize: root.active ? Retro.fsValue : Retro.fsLabel
        font.bold: true
    }
}
