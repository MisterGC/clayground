// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The measurement half of LabTheme: type sizes, spacing steps, shape, and the
// one factor that multiplies all of them.
//
// It lives in plain JS for the same reason palette.js does - `node
// tokens.test.js` can then check the relationships that make a scale a scale
// (monotonic, never collapsing two roles onto one pixel, clamped to a range a
// projector and a laptop can both live with) without a running engine.
//
// Why a scale at all: a lab shown on a 32" screen two metres away needs every
// number here about 60% larger than the same lab on a laptop, and the labs had
// no turnable knob - every font size, panel width and margin was a bare pixel
// literal. One factor, applied at the single point every widget already reads
// its type from, is the smallest thing that fixes that.
//
// The base values are the sizes the kernel chrome actually used before the
// scale existed, so uiScale 1.0 reproduces the old layout pixel for pixel.
//

// --- the scale -------------------------------------------------------------

// Below 0.75 the 10 px role stops resolving on a normal display; above 2.0 a
// 640 px narrator no longer fits a 1280-wide window.
var SCALE_MIN = 0.75
var SCALE_MAX = 2.0

// The rungs A-/A+ steps between. Not a geometric series: the interesting
// region is 1.0 to 1.6 (laptop to lecture room), so it is sampled finer there
// than at the ends.
var SCALE_STEPS = [0.75, 0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0]

function clampScale(v) {
    var n = Number(v)
    if (!isFinite(n)) return 1.0
    return Math.max(SCALE_MIN, Math.min(SCALE_MAX, n))
}

// The next rung in `dir` (+1 / -1), or the current value at the end of the
// ladder. Steps from wherever the scale happens to be, so a value restored
// from storage or set by a flow still lands on the ladder.
function stepScale(cur, dir) {
    var c = clampScale(cur)
    if (dir > 0) {
        for (var i = 0; i < SCALE_STEPS.length; ++i)
            if (SCALE_STEPS[i] > c + 1e-6) return SCALE_STEPS[i]
        return SCALE_STEPS[SCALE_STEPS.length - 1]
    }
    for (var j = SCALE_STEPS.length - 1; j >= 0; --j)
        if (SCALE_STEPS[j] < c - 1e-6) return SCALE_STEPS[j]
    return SCALE_STEPS[0]
}

// --- the roles -------------------------------------------------------------
//
// Seven type roles, because seven distinct sizes were in use and each one was
// carrying a distinction: an axis tick is not a chip is not a narration line.
// Named by job rather than by size, so a widget says what it is showing.

var TYPE = {
    micro: 10,      // axis ticks, budget legend - the smallest thing that reads
    small: 11,      // mono structure: panel titles, row labels, key caps
    body: 12,       // chips, readouts, buttons
    label: 13,      // hand-font labels, scenario notes, help rows
    action: 14,     // flow controls - a thing you click by name
    lead: 15,       // the hint bar and a task's hint
    title: 18       // narration, sized for the back row of a classroom
}

// Spacing ladder. xs is a hairline gap, xxl a panel-to-panel margin.
var SPACE = {
    xs: 3,
    s: 4,
    m: 6,
    l: 8,
    xl: 12,
    xxl: 16
}

// Shape. A border thins out visually as everything around it grows, so it
// scales too - but never below the one pixel that still draws.
var SHAPE = {
    radius: 8,
    border: 2
}

// Any other measurement: a widget writes px(280) where it used to write 280.
function px(v, scale) {
    return Math.max(1, Math.round(Number(v) * clampScale(scale)))
}

// A type size, floored at 6 so the smallest role survives the smallest scale.
function type(role, scale) {
    var base = TYPE[role] !== undefined ? TYPE[role] : TYPE.body
    return Math.max(6, Math.round(base * clampScale(scale)))
}

function space(role, scale) {
    var base = SPACE[role] !== undefined ? SPACE[role] : SPACE.m
    return Math.max(1, Math.round(base * clampScale(scale)))
}

// Percent, for the control that shows what the scale currently is.
function scaleLabel(v) {
    return Math.round(clampScale(v) * 100) + "%"
}
