// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Singleton-ish palette + metrics shared across retro widgets. Import
// relatively and read via Retro.colorX / Retro.sizeY.
//
// Intent-based colour system:
//   teal   → parameters / editable structure
//   pink   → time / playhead / live trigger flash
//   amber  → audio signal (waveform trace, LEDs)
//   red    → clipping / error / heavy load
//   green  → OK / ready / mode indicator
//   cyan   → LED dim state

pragma Singleton
import QtQuick

QtObject {
    // Base surfaces
    readonly property color bg:       "#0a0f1a"
    readonly property color panel:    "#12182a"
    readonly property color panelHi:  "#1d2640"
    readonly property color panelLo:  "#060913"
    readonly property color bevelHi:  "#2d3a5c"
    readonly property color bevelLo:  "#030610"
    readonly property color inset:    "#070b17"

    // Intent
    readonly property color teal:     "#0f9d9a"
    readonly property color tealDim:  "#0a5c5a"
    readonly property color tealLo:   "#083a38"
    readonly property color pink:     "#ff3366"
    readonly property color pinkDim:  "#7a1833"
    readonly property color amber:    "#ffd93d"
    readonly property color amberDim: "#8a7020"
    readonly property color red:      "#ff5050"
    readonly property color redDim:   "#7a2525"
    readonly property color green:    "#4ade80"
    readonly property color greenDim: "#1e6b3a"
    readonly property color cyan:     "#00d9ff"

    // Text
    readonly property color txt:      "#eaeaea"
    readonly property color txtDim:   "#8a8a8a"
    readonly property color txtDark:  "#4a5368"

    // Font
    readonly property string mono: Qt.platform.os === "osx" ? "Menlo" :
                                   Qt.platform.os === "windows" ? "Consolas" : "monospace"
    readonly property int fsLabel:   11
    readonly property int fsValue:   13
    readonly property int fsHeader:  15
    readonly property int fsTitle:   20

    // Pixel grid — align everything to 2 px for the crisp retro feel.
    readonly property int grid: 2
}
