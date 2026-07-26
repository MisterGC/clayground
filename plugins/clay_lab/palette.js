// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The two counterpart palettes behind LabTheme, plus the one rule that has to
// survive a switch.
//
// This is plain JS rather than QML properties for one reason: the same source
// that paints the labs can then be measured by `node palette.test.js`, so a
// palette edit is checked against the relationship that made the original
// value correct instead of against taste. Every number in the DARK block below
// was derived that way and carries its measured ratio.
//
// The doctrine, shared with grafli and textli:
//
//  * The palettes are **counterparts, not inversions**. Light is warm paper
//    (#e8e4dd); dark is the same warm hue family rotated to a low-key ground
//    (#1e1c19 - the exact value both siblings use, so a lab, a board and a
//    document sitting side by side read as one house).
//
//  * Roles that are readable **by luminance** reproduce their contrast ratio
//    against the ground they are actually drawn on - panel ink against the
//    panel, not against the board.
//
//  * Surfaces preserve the *size* of the step they take off the ground. The
//    direction is kept where there is room below a low-key ground and flipped
//    where there is not: a border darker than #1e1c19 is unreachable, so
//    borders lift instead.
//
//  * Anything drawn **on a fill** takes its ink from that fill via inkOn(),
//    never from a pinned constant. A light ink only looks right while the fill
//    happens to be dark, which stops being true the moment the palette lifts
//    that fill.
//
// And the one rule that is specific to labs:
//
//  * Colour that encodes **meaning** keeps its identity across the switch.
//    A lab's paper says "the rose track is GPS" and its legend has to agree in
//    both themes, so the data tokens are not re-derived - they are measured on
//    the dark ground and kept unless they fail to read there. Nine of the
//    twelve survive untouched; only the deep-navy end (primary, forest, plum
//    and four plot series) is lifted, and then only far enough to clear the
//    floor, keeping hue and saturation. This is the same reason grafli leaves
//    its heatmap scale alone while its chrome follows the theme.
//

// --- ink over a fill -------------------------------------------------------

// The endpoints are shared with grafli and textli.
var INK_ON_LIGHT = "#2d2d2d"
var INK_ON_DARK = "#f2f0eb"

// The siblings switch at luma 120; a document has no mid-luma fills to worry
// about. The labs do - teal (#3e9b92, luma 126) and plum (#8160a8, luma 113)
// are chip fills - and a sweep over every fill in both palettes puts the worst
// case at 3.06:1 here against 2.92:1 at the siblings' threshold of 140.
var INK_LUMA_SWITCH = 120

// --- the palettes ----------------------------------------------------------

var LIGHT = {
    name: "light",
    dark: false,

    // paper surfaces
    paper: "#e8e4dd",
    paperDeep: "#dcd7ce",
    panel: "#f5f2ed",
    panelEdge: "#cdc8bf",
    grid: "#cdc8bf",

    // the 3D board, lightest to darkest: sky, the table, the sheet on it.
    // The step between them is what draws a horizon line at low camera angles.
    board: "#f2eee7",
    table: "#e8e4dd",
    sheet: "#dcd7ce",

    // ink
    ink: "#2f3437",
    inkSoft: "#403a30",
    inkFaint: "#8a8580",
    inkSolid: "#2f3437",

    // meaning-bearing tokens
    primary: "#004578",
    secondary: "#0178d4",
    tertiary: "#4ebf71",
    accent: "#d4804e",
    highlight: "#d4ba6a",
    muted: "#b8b3ab",
    soft: "#b0a1ca",
    clay: "#c56c54",
    teal: "#3e9b92",
    rose: "#c98ba8",
    forest: "#3f7a57",
    plum: "#8160a8",
    alarm: "#c05621",

    seriesColors: ["#2b6cb0", "#c05621", "#2f855a", "#805ad5", "#b83280", "#2c7a7b"],

    // 3D lighting. A cast shadow is a percentage of darkening, so how far it
    // may go depends on how much room the ground has left.
    ambient3d: "#737380",
    shadowFactor: 58
}

var DARK = {
    name: "dark",
    dark: true,

    // The ground is grafli's and textli's, to the byte. The rest keep the size
    // of their light step off it: well 1.10 (light 1.13), panel 1.17 (1.14).
    // Borders are the flip - 1.31 *below* #1e1c19 is unreachable, so they lift
    // by the same amount instead and stay the visible line they were.
    paper: "#1e1c19",
    paperDeep: "#141210",
    panel: "#2c2923",
    panelEdge: "#3b372f",
    grid: "#393733",

    // The board inverts as a whole: on paper the sky is the brightest thing
    // and the working sheet the darkest, so in the dark it is the sheet that
    // lifts and the sky that recedes. The horizon line survives either way,
    // which is the only thing the ordering was ever for.
    board: "#141310",
    table: "#1e1c19",
    sheet: "#2a2721",

    // Ink is the light theme's paper - the pairing that makes the two read as
    // counterparts. Measured against the panel: 11.44 (light 11.28),
    // 9.73 (10.08), 3.36 (3.27).
    ink: "#e8e4dd",
    inkSoft: "#d8d3ca",
    inkFaint: "#7e7972",

    // Ink as a lit 3D surface - a board rim, a tunnel wall - rather than as a
    // line. This is the one role that deliberately does *not* reproduce its
    // ratio: on paper a solid ink block is the darkest thing in the scene at
    // 8.79 against the sheet, and the counterpart of that on a dark board is
    // not a pale rim but a light source. It lifts only far enough to read as
    // an edge from either side (2.45 against the sheet, 3.05 against the sky).
    inkSolid: "#6a6154",

    // primary and secondary are read as *text* - titles, key readings, the
    // interactive accent - so they belong with the ink above and reproduce
    // their ratio rather than merely clearing the floor: 8.85 (light 8.86)
    // and 4.05 (4.05). Left at the floor, a deep navy title would have been
    // the quietest thing on the panel instead of the loudest.
    primary: "#94d1ff",
    secondary: "#0189f3",

    // The rest are data tokens, measured on the dark panel and kept unless
    // they fail to read there: tertiary 6.22, accent 4.83, highlight 7.62,
    // muted 6.95, clay 3.90, teal 4.36, rose 5.34, alarm 3.17 - every one of
    // them identical to its light value, because a lab's paper names these
    // colours and the legend has to agree in both themes. Lifted, keeping hue
    // and saturation, only where the light value cannot carry a dark ground:
    tertiary: "#4ebf71",
    accent: "#d4804e",
    highlight: "#d4ba6a",
    muted: "#b8b3ab",
    soft: "#b0a1ca",
    clay: "#c56c54",
    teal: "#3e9b92",
    rose: "#c98ba8",
    forest: "#44835d",      // 2.85 -> 3.21
    plum: "#8869ad",        // 2.88 -> 3.22
    alarm: "#c05621",

    // Same treatment: the two mid-blues and the pink sit just under the floor
    // on a dark ground, the rest are already clear of it. Minimum pairwise
    // separation across the set is 26.7 dE against light's 27.1, so the six
    // stay as tellable apart as they ever were.
    seriesColors: ["#3079c5", "#c05621", "#2f855a", "#8560d7", "#cb3f90", "#2f8283"],

    // A shadow is darkening, and there is far less left to take away from a
    // low-key ground - at the light theme's strength the board turns to mud.
    ambient3d: "#5a5860",
    shadowFactor: 26
}

var PALETTES = { "light": LIGHT, "dark": DARK }

var ROLES = ["paper", "paperDeep", "panel", "panelEdge", "grid",
             "board", "table", "sheet",
             "ink", "inkSoft", "inkFaint", "inkSolid",
             "primary", "secondary", "tertiary", "accent", "highlight",
             "muted", "soft", "clay", "teal", "rose", "forest", "plum", "alarm"]

// --- colour maths ----------------------------------------------------------
//
// Accepts either a hex string or a QML color (whose channels are 0..1), so the
// same helpers serve the running lab and the node suite.

function rgbOf(c) {
    if (typeof c === "string") {
        var h = c.charAt(0) === "#" ? c.substring(1) : c
        if (h.length === 3)
            h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1)
                + h.charAt(2) + h.charAt(2)
        if (h.length === 8) h = h.substring(2)   // QML's #AARRGGBB
        return [parseInt(h.substring(0, 2), 16),
                parseInt(h.substring(2, 4), 16),
                parseInt(h.substring(4, 6), 16)]
    }
    return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)]
}

function _channel(v) {
    v = v / 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
}

// WCAG relative luminance.
function luminance(c) {
    var p = rgbOf(c)
    return 0.2126 * _channel(p[0]) + 0.7152 * _channel(p[1]) + 0.0722 * _channel(p[2])
}

// WCAG contrast ratio, 1..21.
function contrast(a, b) {
    var la = luminance(a), lb = luminance(b)
    var hi = Math.max(la, lb), lo = Math.min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
}

function _toHsl(p) {
    var r = p[0] / 255, g = p[1] / 255, b = p[2] / 255
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b)
    var h = 0, s = 0, l = (mx + mn) / 2
    if (mx !== mn) {
        var d = mx - mn
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        if (mx === r) h = (g - b) / d + (g < b ? 6 : 0)
        else if (mx === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h /= 6
    }
    return [h, s, l]
}

function _fromHsl(h, s, l) {
    var hex = function (v) {
        var t = Math.max(0, Math.min(255, Math.round(v * 255))).toString(16)
        return t.length < 2 ? "0" + t : t
    }
    if (s === 0) return "#" + hex(l) + hex(l) + hex(l)
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s
    var p = 2 * l - q
    var f = function (t) {
        if (t < 0) t += 1
        if (t > 1) t -= 1
        if (t < 1 / 6) return p + (q - p) * 6 * t
        if (t < 1 / 2) return q
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
        return p
    }
    return "#" + hex(f(h + 1 / 3)) + hex(f(h)) + hex(f(h - 1 / 3))
}

// Nudge `c` away from the ground by `amount` (a Qt.lighter/darker style factor
// above 1), in whichever direction the palette has room.
//
// A grid line on paper is drawn by taking light *away* from the sheet; on a
// low-key ground there is none left to take, so the same line has to be drawn
// by adding it. Callers say how far, not which way, which is the only form of
// the instruction that survives a theme switch.
function step(c, amount, isDark) {
    var hsl = _toHsl(rgbOf(c))
    var l = isDark ? Math.min(1, hsl[2] * amount) : hsl[2] / amount
    return _fromHsl(hsl[0], hsl[1], l)
}

// Readable ink for anything drawn on top of `fill`.
//
// Every chip, badge and pill goes through here. The rule is deliberately about
// the fill and not about the theme: a chip whose fill the palette lifts gets
// dark ink automatically, which is the failure mode this exists to close.
function inkOn(fill) {
    var p = rgbOf(fill)
    var luma = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
    return luma > INK_LUMA_SWITCH ? INK_ON_LIGHT : INK_ON_DARK
}
