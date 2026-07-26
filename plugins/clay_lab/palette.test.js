// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/palette.test.js
//
// The two counterpart palettes, and the relationships that have to survive a
// switch. These assert *rules*, not colours: a palette edit is checked against
// the relationship that made the original value correct, so the class of bug
// where a value is carried across the inversion - a light ink left pinned over
// a fill the dark palette lifted - fails here rather than in the eye.
//
// Uses the kit harness; a test reaching across for a test harness is the one
// direction this dependency runs.

const K = require('../../labs/kits/kitcheck.js')
const P = K.load(__dirname, 'palette.js',
    ['LIGHT', 'DARK', 'PALETTES', 'ROLES', 'inkOn', 'contrast', 'luminance',
     'INK_ON_LIGHT', 'INK_ON_DARK', 'INK_LUMA_SWITCH', 'step'])

const BOTH = [P.LIGHT, P.DARK]

// CIE76 dE - enough to say whether two categorical colours are tellable apart.
function lab(hex) {
    const h = hex.replace('#', '')
    const f = v => {
        v = parseInt(v, 16) / 255
        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }
    const r = f(h.slice(0, 2)), g = f(h.slice(2, 4)), b = f(h.slice(4, 6))
    const k = v => v > 0.008856 ? Math.cbrt(v) : (7.787 * v + 16 / 116)
    const x = k((r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047)
    const y = k(r * 0.2126 + g * 0.7152 + b * 0.0722)
    const z = k((r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883)
    return [116 * y - 16, 500 * (x - y), 200 * (y - z)]
}
function deltaE(a, b) {
    const A = lab(a), B = lab(b)
    return Math.hypot(A[0] - B[0], A[1] - B[1], A[2] - B[2])
}
function minPairwise(list) {
    let m = Infinity
    for (let i = 0; i < list.length; i++)
        for (let j = i + 1; j < list.length; j++)
            m = Math.min(m, deltaE(list[i], list[j]))
    return m
}

// ---------------------------------------------------------------- structure

K.section('structure')

let complete = true
for (const p of BOTH)
    for (const role of P.ROLES)
        if (typeof p[role] !== 'string' || p[role].charAt(0) !== '#') complete = false
K.ok('both palettes define every role as a colour', complete)

K.eq('seriesColors have the same length in both',
     P.DARK.seriesColors.length, P.LIGHT.seriesColors.length)

K.ok('the palettes are named and flagged',
     P.LIGHT.name === 'light' && !P.LIGHT.dark
     && P.DARK.name === 'dark' && P.DARK.dark)

K.ok('the ground is the value grafli and textli use',
     P.DARK.paper.toLowerCase() === '#1e1c19', P.DARK.paper)

// ---------------------------------------------------- the ground/ink pairing

K.section('ground and ink')

K.ok('light ink is darker than its panel',
     P.contrast(P.LIGHT.ink, P.LIGHT.panel) > 1
     && P.luminance(P.LIGHT.ink) < P.luminance(P.LIGHT.panel))
K.ok('dark ink is lighter than its panel - the relationship inverts',
     P.luminance(P.DARK.ink) > P.luminance(P.DARK.panel))

for (const p of BOTH)
    K.ok('body ink is readable on the panel (' + p.name + ')',
         P.contrast(p.ink, p.panel) >= 7.0,
         P.contrast(p.ink, p.panel).toFixed(2))

// Roles read as text reproduce how loud they are meant to be, measured against
// the panel they are drawn on rather than against the board.
for (const role of ['ink', 'inkSoft', 'inkFaint', 'primary', 'secondary']) {
    const l = P.contrast(P.LIGHT[role], P.LIGHT.panel)
    const d = P.contrast(P.DARK[role], P.DARK.panel)
    K.near(role + ' keeps its contrast role across the switch', d, l, l * 0.15)
}

// ------------------------------------------------------------- the surfaces

K.section('surfaces')

// A panel reads as a container because of how far it sits from the ground.
// The size of that step is the relationship; the direction is free to flip
// where a low-key ground leaves no room below it.
for (const role of ['paperDeep', 'panel', 'panelEdge', 'grid']) {
    const l = P.contrast(P.LIGHT[role], P.LIGHT.paper)
    const d = P.contrast(P.DARK[role], P.DARK.paper)
    K.near(role + ' steps off the ground by the same amount', d, l, l * 0.15)
}

K.ok('a floating panel lifts off the ground in both themes',
     P.luminance(P.LIGHT.panel) > P.luminance(P.LIGHT.paper)
     && P.luminance(P.DARK.panel) > P.luminance(P.DARK.paper))

K.ok('a recessed well sinks below the panel in both themes',
     P.luminance(P.LIGHT.paperDeep) < P.luminance(P.LIGHT.panel)
     && P.luminance(P.DARK.paperDeep) < P.luminance(P.DARK.panel))

K.ok('borders stay visible against the ground in both themes',
     P.contrast(P.LIGHT.panelEdge, P.LIGHT.paper) > 1.2
     && P.contrast(P.DARK.panelEdge, P.DARK.paper) > 1.2)

// ------------------------------------------------------------- the 3D board

K.section('the 3D board')

// Sky, table and sheet are three steps that draw a horizon at low camera
// angles. On paper the sky is brightest and the sheet darkest; in the dark the
// whole ordering inverts, which is what keeps the horizon readable rather than
// leaving the sheet to vanish into the void.
K.ok('light: sky over table over sheet',
     P.luminance(P.LIGHT.board) > P.luminance(P.LIGHT.table)
     && P.luminance(P.LIGHT.table) > P.luminance(P.LIGHT.sheet))
K.ok('dark: the ordering inverts - sheet over table over sky',
     P.luminance(P.DARK.sheet) > P.luminance(P.DARK.table)
     && P.luminance(P.DARK.table) > P.luminance(P.DARK.board))

K.near('the sky-to-table step survives',
       P.contrast(P.DARK.board, P.DARK.table),
       P.contrast(P.LIGHT.board, P.LIGHT.table),
       P.contrast(P.LIGHT.board, P.LIGHT.table) * 0.15)
K.near('the table-to-sheet step survives',
       P.contrast(P.DARK.sheet, P.DARK.table),
       P.contrast(P.LIGHT.sheet, P.LIGHT.table),
       P.contrast(P.LIGHT.sheet, P.LIGHT.table) * 0.15)

// Solid ink is the deliberate exception to reproducing a ratio: a board rim is
// a lit surface, so the counterpart of "darkest thing in the scene" would be a
// light source. It has to read as an edge from both sides and no more.
for (const p of BOTH) {
    K.ok('solid ink reads against the sheet (' + p.name + ')',
         P.contrast(p.inkSolid, p.sheet) >= 2.2, P.contrast(p.inkSolid, p.sheet).toFixed(2))
    K.ok('solid ink reads against the sky (' + p.name + ')',
         P.contrast(p.inkSolid, p.board) >= 2.2, P.contrast(p.inkSolid, p.board).toFixed(2))
}
K.ok('solid ink does not outshine the body ink in the dark',
     P.luminance(P.DARK.inkSolid) < P.luminance(P.DARK.ink),
     'a rim brighter than the text would own the screen')

// step() says how far, not which way - so it has to move away from the ground
// in both themes, and back toward it for an amount below 1.
K.ok('step() lifts on a dark ground and sinks on a light one',
     P.luminance(P.step('#808080', 1.3, true)) > P.luminance('#808080')
     && P.luminance(P.step('#808080', 1.3, false)) < P.luminance('#808080'))
K.ok('step() below 1 reverses, in both themes',
     P.luminance(P.step('#808080', 0.86, true)) < P.luminance('#808080')
     && P.luminance(P.step('#808080', 0.86, false)) > P.luminance('#808080'))

// A cast shadow removes light. A low-key ground has far less to give up, so
// the light theme's strength would crush it.
K.ok('shadows are weaker on a dark ground',
     P.DARK.shadowFactor < P.LIGHT.shadowFactor,
     P.LIGHT.shadowFactor + ' -> ' + P.DARK.shadowFactor)

// ------------------------------------------------------------- data tokens

K.section('data tokens')

const DATA = ['tertiary', 'accent', 'highlight', 'muted', 'soft', 'clay',
              'teal', 'rose', 'forest', 'plum', 'alarm']

// The lab-specific rule: a colour that encodes meaning is named by the lab's
// paper and drawn in its legend, so it may only change when it has to.
let kept = DATA.filter(r => P.LIGHT[r] === P.DARK[r]).length
K.ok('most data tokens keep their exact identity across the switch',
     kept >= DATA.length * 0.7, kept + '/' + DATA.length + ' unchanged')

for (const role of DATA.concat(['primary', 'secondary'])) {
    const c = P.contrast(P.DARK[role], P.DARK.panel)
    K.ok(role + ' reads on the dark panel', c >= 3.0, c.toFixed(2))
}

// Where a token had to move, it moved along its own hue - a lifted green is
// still the same green, or the legend stops matching the paper.
for (const role of DATA.concat(['secondary'])) {
    if (P.LIGHT[role] === P.DARK[role]) continue
    K.ok(role + ' was lifted, not recoloured', deltaE(P.LIGHT[role], P.DARK[role]) < 20,
         'dE ' + deltaE(P.LIGHT[role], P.DARK[role]).toFixed(1))
}

// Plot series are read against each other, so staying tellable apart is the
// job - more than any individual ratio.
const sepLight = minPairwise(P.LIGHT.seriesColors)
const sepDark = minPairwise(P.DARK.seriesColors)
K.ok('plot series stay as separable as they are on paper',
     sepDark >= sepLight * 0.9,
     'light ' + sepLight.toFixed(1) + ' dE, dark ' + sepDark.toFixed(1) + ' dE')

for (const p of BOTH)
    for (let i = 0; i < p.seriesColors.length; i++) {
        const c = P.contrast(p.seriesColors[i], p.panel)
        K.ok('series[' + i + '] reads on the ' + p.name + ' panel', c >= 3.0, c.toFixed(2))
    }

// ------------------------------------------------------------------- inkOn

K.section('ink over a fill')

K.ok('inkOn flips with the fill, not with the theme',
     P.inkOn('#1e1c19') === P.INK_ON_DARK && P.inkOn('#e8e4dd') === P.INK_ON_LIGHT)

K.ok('inkOn accepts a QML colour as well as hex',
     P.inkOn({ r: 0.91, g: 0.89, b: 0.87 }) === P.INK_ON_LIGHT)

// The regression this whole file exists for: every fill a chip can wear must
// carry readable ink in both themes. Bold text at chip size clears at 3:1.
let worst = { ratio: Infinity }
for (const p of BOTH) {
    const fills = DATA.concat(['primary', 'secondary'])
        .map(r => p[r]).concat(p.seriesColors, [p.panel, p.paper, p.sheet])
    for (const fill of fills) {
        const ratio = P.contrast(P.inkOn(fill), fill)
        if (ratio < worst.ratio) worst = { ratio: ratio, fill: fill, theme: p.name }
        K.ok('inkOn(' + fill + ') is readable in ' + p.name, ratio >= 3.0, ratio.toFixed(2))
    }
}
console.log('  worst inkOn pairing: ' + worst.fill + ' in ' + worst.theme
            + ' at ' + worst.ratio.toFixed(2) + ':1')

// --------------------------------------------------------------- switching

K.section('switching')

K.ok('both palettes are reachable by name',
     P.PALETTES.light === P.LIGHT && P.PALETTES.dark === P.DARK)

process.exit(K.report('lab palette'))
