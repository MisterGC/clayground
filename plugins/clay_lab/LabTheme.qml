// (c) Clayground Contributors - MIT License, see "LICENSE" file
pragma Singleton

import QtQuick

/*!
    \qmltype LabTheme
    \inqmlmodule Clayground.Lab
    \brief Shared paper-and-ink design tokens for lab UIs.

    A warm, retro-print theme: paper surfaces, charcoal ink lines, a
    muted color set where every hue encodes meaning, monospace type for
    structure and a handwriting face for hints. Kernel widgets
    (ParamPanel, Plot2D) consume it; labs pick their part colors from
    the named tokens so all labs read as one family.

    Example usage:
    \qml
    import Clayground.Lab

    Rectangle {
        color: LabTheme.panel
        border.color: LabTheme.panelEdge
        radius: LabTheme.radius
        Text { text: "hello"; color: LabTheme.ink; font.families: LabTheme.monoFamilies }
    }
    \endqml

    \sa ParamPanel, Plot2D
*/
QtObject {
    // --- paper surfaces ---------------------------------------------------
    readonly property color paper: "#e8e4dd"        // scene / board background
    readonly property color paperDeep: "#dcd7ce"    // recessed paper (board wells)
    readonly property color panel: "#f5f2ed"        // floating panels / cards
    readonly property color panelEdge: "#cdc8bf"    // quiet panel borders, grids
    readonly property color grid: "#cdc8bf"         // peg dots, plot grids

    // --- ink --------------------------------------------------------------
    readonly property color ink: "#2f3437"          // primary lines and text
    readonly property color inkSoft: "#403a30"      // body text
    readonly property color inkFaint: "#8a8580"     // hints, secondary text

    // --- core tokens (meaning-bearing, muted) -----------------------------
    readonly property color primary: "#004578"      // titles, key readings
    readonly property color secondary: "#0178d4"    // interactive / focus
    readonly property color tertiary: "#4ebf71"     // success / active
    readonly property color accent: "#d4804e"       // warm accent (terracotta)
    readonly property color highlight: "#d4ba6a"    // mustard gold
    readonly property color muted: "#b8b3ab"
    readonly property color soft: "#b0a1ca"

    // --- named extras -----------------------------------------------------
    readonly property color clay: "#c56c54"
    readonly property color teal: "#3e9b92"
    readonly property color rose: "#c98ba8"
    readonly property color forest: "#3f7a57"
    readonly property color plum: "#8160a8"
    readonly property color alarm: "#c05621"        // warnings, shorts

    // wire / series set: distinguishable but calm on paper
    readonly property var seriesColors: ["#2b6cb0", "#c05621", "#2f855a", "#805ad5",
                                         "#b83280", "#2c7a7b"]

    // --- shape ------------------------------------------------------------
    readonly property int radius: 8
    readonly property int borderWidth: 2

    // --- type -------------------------------------------------------------
    // structure: mono (retro terminal); hints/notes: handwriting.
    // Resolved once against the installed families - graceful fallbacks.
    readonly property string monoFont: _pick(["JetBrainsMono Nerd Font",
        "JetBrains Mono", "Menlo", "Consolas", "DejaVu Sans Mono"], "Courier")
    readonly property string handFont: _pick(["Patrick Hand", "Bradley Hand",
        "Chalkboard SE", "Comic Sans MS"], "")

    function _pick(want, fallback) {
        const have = Qt.fontFamilies()
        for (const f of want) if (have.indexOf(f) !== -1) return f
        return fallback
    }
}
