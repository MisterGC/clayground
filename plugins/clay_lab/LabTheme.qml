// (c) Clayground Contributors - MIT License, see "LICENSE" file
pragma Singleton

import QtQuick
import "palette.js" as Palette

/*!
    \qmltype LabTheme
    \inqmlmodule Clayground.Lab
    \brief Shared paper-and-ink design tokens for lab UIs, in light and dark.

    A warm, retro-print theme: paper surfaces, charcoal ink lines, a
    muted color set where every hue encodes meaning, monospace type for
    structure and a handwriting face for hints. Kernel widgets
    (ParamPanel, Plot2D) consume it; labs pick their part colors from
    the named tokens so all labs read as one family.

    Every role exists in both a light and a dark palette, and \l mode swaps
    between them at runtime - the roles are ordinary bindings, so a lab that
    reads \c LabTheme.panel follows the switch without doing anything. Drop a
    \l ThemeSwitch into a corner to offer it.

    The two palettes are counterparts rather than inversions, and the rules
    that make them so are written down (and tested) in \c palette.js. The one
    a lab has to know about is \l inkOn(): anything drawn \e on a fill must
    take its ink from that fill, because a pinned light ink stops being
    readable the moment the palette lifts the fill under it.

    Example usage:
    \qml
    import Clayground.Lab

    Rectangle {
        color: LabTheme.panel
        border.color: LabTheme.panelEdge
        radius: LabTheme.radius
        Text { text: "hello"; color: LabTheme.ink; font.family: LabTheme.monoFont }
    }

    Rectangle {                          // a chip, whose fill changes with state
        color: active ? LabTheme.secondary : LabTheme.panel
        Text { text: "on"; color: LabTheme.inkOn(parent.color) }
    }
    \endqml

    \sa ParamPanel, Plot2D, ThemeSwitch
*/
QtObject {
    id: _theme

    /*!
        \qmlproperty string LabTheme::mode
        \brief The active palette: \c "light" (default) or \c "dark".
    */
    property string mode: "light"

    /*! \qmlproperty bool LabTheme::dark \readonly \brief True while the dark palette is active. */
    readonly property bool dark: mode === "dark"

    /*! \qmlproperty var LabTheme::modes \readonly \brief The palette names on offer. */
    readonly property var modes: ["light", "dark"]

    // The active palette. Every role below reads through it, so one assignment
    // to `mode` re-evaluates the whole theme wherever it is used.
    readonly property var _p: Palette.PALETTES[mode] !== undefined
                              ? Palette.PALETTES[mode] : Palette.LIGHT

    // --- paper surfaces ---------------------------------------------------
    readonly property color paper: _p.paper          // scene / board background
    readonly property color paperDeep: _p.paperDeep  // recessed paper (board wells)
    readonly property color panel: _p.panel          // floating panels / cards
    readonly property color panelEdge: _p.panelEdge  // quiet panel borders, grids
    readonly property color grid: _p.grid            // peg dots, plot grids

    // --- the 3D board -----------------------------------------------------
    // Three steps that draw a horizon line at low camera angles. They are
    // named separately from the 2D surfaces because the ordering inverts in
    // the dark while a recessed 2D well still has to sink.
    readonly property color board: _p.board          // the sky (SceneEnvironment clearColor)
    readonly property color table: _p.table          // the table the board lies on
    readonly property color sheet: _p.sheet          // the pegboard / plan sheet

    // --- ink --------------------------------------------------------------
    readonly property color ink: _p.ink              // primary lines and text
    readonly property color inkSoft: _p.inkSoft      // body text
    readonly property color inkFaint: _p.inkFaint    // hints, secondary text
    // Ink as a lit 3D surface (board rims, walls) rather than as a line: on a
    // dark board a full-strength counterpart of solid ink would glow.
    readonly property color inkSolid: _p.inkSolid

    // --- core tokens (meaning-bearing, muted) -----------------------------
    readonly property color primary: _p.primary      // titles, key readings
    readonly property color secondary: _p.secondary  // interactive / focus
    readonly property color tertiary: _p.tertiary    // success / active
    readonly property color accent: _p.accent        // warm accent (terracotta)
    readonly property color highlight: _p.highlight  // mustard gold
    readonly property color muted: _p.muted
    readonly property color soft: _p.soft

    // --- named extras -----------------------------------------------------
    readonly property color clay: _p.clay
    readonly property color teal: _p.teal
    readonly property color rose: _p.rose
    readonly property color forest: _p.forest
    readonly property color plum: _p.plum
    readonly property color alarm: _p.alarm          // warnings, shorts

    // wire / series set: distinguishable but calm on paper
    readonly property var seriesColors: _p.seriesColors

    // --- 3D lighting ------------------------------------------------------
    /*!
        \qmlproperty color LabTheme::ambient3d
        \brief Ambient fill for a scene lit by a single key light.
    */
    readonly property color ambient3d: _p.ambient3d

    /*!
        \qmlproperty int LabTheme::shadowFactor
        \brief How hard a cast shadow lands, as \c DirectionalLight expects it.

        A shadow removes light, and a low-key ground has much less to give up
        before it turns to mud - so this drops in the dark rather than staying
        put.
    */
    readonly property int shadowFactor: _p.shadowFactor

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

    /*!
        \qmlmethod color LabTheme::inkOn(color fill)
        \brief Readable text color for anything drawn on top of \a fill.

        Use this for every chip, badge and pill instead of naming a light or
        dark ink directly. The choice follows the \e fill, not the theme, so a
        chip keeps readable text whichever palette lifted or sank it.
    */
    function inkOn(fill) { return Palette.inkOn(fill) }

    /*!
        \qmlmethod color LabTheme::step(color c, real amount)
        \brief Moves \a c away from the ground by \a amount, whichever way the
        palette has room.

        The replacement for \c Qt.darker() on anything that has to stay visible
        in both themes: a grid line drawn by taking light away from the sheet
        has nothing left to take on a dark ground, so it is drawn by adding
        light instead. Say how far, not which way. An \a amount below 1 moves
        the other way, back \e toward the ground.
    */
    function step(c, amount) { return Palette.step(c, amount, dark) }

    /*!
        \qmlmethod real LabTheme::contrast(color a, color b)
        \brief The WCAG contrast ratio between \a a and \a b, 1 to 21.
    */
    function contrast(a, b) { return Palette.contrast(a, b) }

    /*!
        \qmlmethod void LabTheme::toggle()
        \brief Switches to the other palette.
    */
    function toggle() { mode = dark ? "light" : "dark" }

    function _pick(want, fallback) {
        const have = Qt.fontFamilies()
        for (const f of want) if (have.indexOf(f) !== -1) return f
        return fallback
    }
}
