// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/tokens.test.js
//
// The type and spacing scale, checked the way palette.test.js checks the
// palettes: against the relationships that make a scale a scale, not against
// the numbers. A size table is easy to edit and easy to break silently - two
// roles rounding onto the same pixel, a scale that stops growing, a step that
// disappears at the small end - and none of those show up until someone runs
// a lab on the screen the whole feature exists for.

const K = require('../../labs/kits/kitcheck.js')
const T = K.load(__dirname, 'tokens.js',
    ['SCALE_MIN', 'SCALE_MAX', 'SCALE_STEPS', 'TYPE', 'SPACE', 'SHAPE',
     'clampScale', 'stepScale', 'px', 'type', 'space', 'scaleLabel'])

const TYPE_ROLES = ['micro', 'small', 'body', 'label', 'action', 'lead', 'title']
const SPACE_ROLES = ['xs', 's', 'm', 'l', 'xl', 'xxl']
// every scale a lab can actually be in, plus the ends
const SCALES = T.SCALE_STEPS.concat([T.SCALE_MIN, T.SCALE_MAX, 1.0])

// ------------------------------------------------------------------- ladder

K.section('the scale ladder')

K.ok('the ladder starts and ends at the clamp',
     T.SCALE_STEPS[0] === T.SCALE_MIN
     && T.SCALE_STEPS[T.SCALE_STEPS.length - 1] === T.SCALE_MAX)

let rising = true
for (let i = 1; i < T.SCALE_STEPS.length; ++i)
    if (T.SCALE_STEPS[i] <= T.SCALE_STEPS[i - 1]) rising = false
K.ok('the ladder rises', rising, T.SCALE_STEPS.join(' '))

K.ok('1.0 is a rung - the default has to be reachable by stepping back',
     T.SCALE_STEPS.indexOf(1.0) !== -1)

K.eq('clamp holds the bottom', T.clampScale(0.1), T.SCALE_MIN)
K.eq('clamp holds the top', T.clampScale(99), T.SCALE_MAX)
K.eq('clamp survives nonsense', T.clampScale('what'), 1.0)
K.eq('clamp survives an undefined stored preference', T.clampScale(undefined), 1.0)

K.ok('stepping up from the top stays at the top',
     T.stepScale(T.SCALE_MAX, 1) === T.SCALE_MAX)
K.ok('stepping down from the bottom stays at the bottom',
     T.stepScale(T.SCALE_MIN, -1) === T.SCALE_MIN)

// A value restored from storage need not be on the ladder; stepping from it
// must still land on a rung rather than drift by a fixed increment forever.
K.ok('an off-ladder value steps onto the ladder',
     T.SCALE_STEPS.indexOf(T.stepScale(1.07, 1)) !== -1
     && T.SCALE_STEPS.indexOf(T.stepScale(1.07, -1)) !== -1)

K.ok('up then down returns to where it started',
     T.stepScale(T.stepScale(1.0, 1), -1) === 1.0)

// ------------------------------------------------------------------- type

K.section('the type scale')

for (const s of SCALES) {
    let mono = true
    for (let i = 1; i < TYPE_ROLES.length; ++i)
        if (T.type(TYPE_ROLES[i], s) < T.type(TYPE_ROLES[i - 1], s)) mono = false
    K.ok('type roles never invert at scale ' + s, mono,
         TYPE_ROLES.map(r => T.type(r, s)).join(' '))
}

// The whole point of a scale: turning it up has to actually make things
// bigger. Rounding could otherwise leave two adjacent rungs identical.
for (const role of TYPE_ROLES) {
    let grows = true
    for (let i = 1; i < T.SCALE_STEPS.length; ++i)
        if (T.type(role, T.SCALE_STEPS[i]) <= T.type(role, T.SCALE_STEPS[i - 1]))
            grows = false
    K.ok('font.' + role + ' grows at every rung', grows,
         T.SCALE_STEPS.map(s => T.type(role, s)).join(' '))
}

K.ok('scale 1.0 reproduces the sizes the chrome had before the scale existed',
     TYPE_ROLES.every(r => T.type(r, 1.0) === T.TYPE[r]),
     TYPE_ROLES.map(r => r + '=' + T.type(r, 1.0)).join(' '))

// The smallest role at the smallest scale still has to be a font.
K.ok('the smallest role stays legible at the smallest scale',
     T.type('micro', T.SCALE_MIN) >= 7, T.type('micro', T.SCALE_MIN))

// A title has to stay a title: the distance between the ends of the scale is
// what makes seven roles worth having rather than one.
for (const s of SCALES)
    K.ok('title clearly outsizes micro at scale ' + s,
         T.type('title', s) >= T.type('micro', s) * 1.6,
         T.type('micro', s) + ' -> ' + T.type('title', s))

// ------------------------------------------------------------------ spacing

K.section('the spacing scale')

for (const s of SCALES) {
    let mono = true
    for (let i = 1; i < SPACE_ROLES.length; ++i)
        if (T.space(SPACE_ROLES[i], s) < T.space(SPACE_ROLES[i - 1], s)) mono = false
    K.ok('spacing roles never invert at scale ' + s, mono,
         SPACE_ROLES.map(r => T.space(r, s)).join(' '))
}

K.ok('spacing never collapses to zero',
     SCALES.every(s => SPACE_ROLES.every(r => T.space(r, s) >= 1)))

K.ok('scale 1.0 reproduces the spacing the chrome had',
     SPACE_ROLES.every(r => T.space(r, 1.0) === T.SPACE[r]))

// --------------------------------------------------------------- px and shape

K.section('measurements')

K.eq('px is the identity at 1.0', T.px(280, 1.0), 280)
K.eq('px scales a panel width', T.px(280, 1.5), 420)
K.ok('px never rounds a measurement away',
     SCALES.every(s => T.px(1, s) >= 1))

// Everything a widget draws has to move together, or a 640-wide narrator at
// 1.6 gets 18px type in a 640px box.
for (const s of SCALES) {
    const ratio = T.px(640, s) / 640
    K.near('a panel width tracks the scale at ' + s, ratio, T.clampScale(s), 0.02)
}

K.ok('a border stays at least one pixel at every scale',
     SCALES.every(s => T.px(T.SHAPE.border, s) >= 1))

K.ok('the radius keeps up with the padding it rounds',
     SCALES.every(s => T.px(T.SHAPE.radius, s) >= T.space('m', s)))

// ---------------------------------------------------------------- the label

K.section('the readout')

K.eq('the switch reads back a percentage', T.scaleLabel(1.3), '130%')
K.eq('the default reads 100%', T.scaleLabel(1.0), '100%')
K.eq('an out-of-range preference reads back clamped',
     T.scaleLabel(9), Math.round(T.SCALE_MAX * 100) + '%')

process.exit(K.report('lab tokens'))
