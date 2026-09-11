// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The character kit's model: what a sheet of frozen figures is made of, and
// the few numbers a lab quotes about characters that are not the plugin's
// own to quote.
//
// Deliberately Qt-free (.pragma library, no engine, no clock, no randomness)
// so `node labs/kits/character/sheet.test.js` checks it in a second. The
// animation models themselves - gait.js, action.js, martialarts.js - live
// with the plugin and have their own suites; this file is the layer a LAB
// needs on top of them: where the figures of a sheet stand, what a phase is
// called, which builds a lineup shows, and how far apart six faces are.

.pragma library

// --- phases of a cycle ----------------------------------------------------

// What a phase of a walk is called. t = 0 and 0.5 are the CONTACTS (legs
// furthest apart, the leading heel down), 0.25 and 0.75 the PASSING positions
// (legs crossing, the free knee at its highest). Anything else is between.
function phaseKind(t) {
    var u = t - Math.floor(t)
    function near(a) { return Math.abs(u - a) < 1e-6 }
    if (near(0) || near(0.5) || near(1)) return "contact"
    if (near(0.25) || near(0.75)) return "passing"
    return ""
}

// Where a clock stands in a cycle of cycleS seconds, 0..1.
function phaseOf(time, cycleS) {
    if (!(cycleS > 0)) return 0
    var u = (time / cycleS) % 1
    return u < 0 ? u + 1 : u
}

// --- where a row of figures stands ----------------------------------------

// n figures spaced `spacing` apart along X, centred on the origin, so a lab
// can frame the row about its own home pivot. `span` is the width the row
// covers including half a spacing either side - what a floor or a frame
// wants.
function layout(n, spacing) {
    var xs = []
    for (var i = 0; i < n; ++i) xs.push((i - (n - 1) / 2) * spacing)
    return { xs: xs, span: n * spacing }
}

// --- the six faces ---------------------------------------------------------

var EXPRESSIONS = ["neutral", "happy", "sad", "angry", "disgust", "surprised"]

// The ten numbers an expression is made of, in the order the plugin's face
// suite asserts on them. browAngle is degrees where everything else is a
// fraction, so a distance treats thirty degrees as one unit.
var FACE_KEYS = ["cornerLift", "skew", "open", "wide", "round",
                 "hood", "squint", "browAngle", "browRise", "browSkew"]
var BROW_DEG_PER_UNIT = 30

function faceDistance(a, b) {
    var s = 0
    for (var i = 0; i < FACE_KEYS.length; ++i) {
        var k = FACE_KEYS[i]
        var d = (Number(a[k]) || 0) - (Number(b[k]) || 0)
        if (k === "browAngle") d /= BROW_DEG_PER_UNIT
        s += d * d
    }
    return Math.sqrt(s)
}

// The smallest distance between any two faces of a set: the one number that
// says "these are distinguishable" about the SET rather than about a face.
// Zero means two of them are the same face.
function distinctness(faces) {
    var best = Infinity
    for (var i = 0; i < faces.length; ++i)
        for (var j = i + 1; j < faces.length; ++j)
            best = Math.min(best, faceDistance(faces[i], faces[j]))
    return faces.length < 2 ? 0 : best
}

// --- the gesture set --------------------------------------------------------

// One column per gesture, in reading order. `kind` says how a column is
// driven: "rest" leaves the idle pose, "hand" only shapes the fingers,
// "gesture" runs the real GestureAnim solver, "action" freezes a cycle at a
// phase. The action phases are the peaks of action.js's jab1 and cross slots
// and the two beats of the working loop worth judging.
var GESTURES = [
    { name: "idle",      kind: "rest" },
    { name: "relax",     kind: "hand" },
    { name: "open",      kind: "hand" },
    { name: "fist",      kind: "hand" },
    { name: "thumbsUp",  kind: "gesture" },
    { name: "point",     kind: "gesture" },
    { name: "pointHigh", kind: "gesture" },
    { name: "present",   kind: "gesture" },
    { name: "guard",     kind: "action", action: "fight", at: 0.95 },
    { name: "jab",       kind: "action", action: "fight", at: 0.084 },
    { name: "cross",     kind: "action", action: "fight", at: 0.605 },
    { name: "work",      kind: "action", action: "use",   at: 0.45 },
    { name: "reach",     kind: "action", action: "use",   at: 0.10 }
]

function gestureNamed(name) {
    for (var i = 0; i < GESTURES.length; ++i)
        if (GESTURES[i].name === name) return GESTURES[i]
    return null
}

// --- the lineup --------------------------------------------------------------

// Six builds, one per corner of ParametricCharacter's slider space, so "one
// gait on every body" is a claim about the whole range and not about the
// default figure. The numbers are the demo's archetypes.
var BUILDS = [
    { name: "player",   bodyHeight: 10.0, realism: 0.3, maturity: 0.5, femininity: 0.4, mass: 0.5,  muscle: 0.6,
      skin: "#fdbcb4", hair: "#8b4513", top: "#4169e1", bottom: "#2c3e50" },
    { name: "thinker",  bodyHeight: 9.0,  realism: 0.6, maturity: 0.7, femininity: 0.5, mass: 0.2,  muscle: 0.2,
      skin: "#e8beac", hair: "#3d3d3d", top: "#5d4e37", bottom: "#3d3d3d" },
    { name: "eater",    bodyHeight: 10.0, realism: 0.2, maturity: 0.5, femininity: 0.4, mass: 0.9,  muscle: 0.2,
      skin: "#fdbcb4", hair: "#8b4513", top: "#e74c3c", bottom: "#8b4513" },
    { name: "hero",     bodyHeight: 11.0, realism: 0.3, maturity: 0.5, femininity: 0.2, mass: 0.4,  muscle: 0.9,
      skin: "#d4a574", hair: "#1a1a1a", top: "#3498db", bottom: "#2c3e50" },
    { name: "child",    bodyHeight: 6.0,  realism: 0.0, maturity: 0.0, femininity: 0.5, mass: 0.5,  muscle: 0.3,
      skin: "#ffe0bd", hair: "#ff6b35", top: "#9b59b6", bottom: "#3498db" },
    { name: "stylized", bodyHeight: 9.5,  realism: 0.5, maturity: 0.5, femininity: 0.85, mass: 0.35, muscle: 0.4,
      skin: "#e8beac", hair: "#2c1810", top: "#e91e63", bottom: "#37474f" }
]

function buildNamed(name) {
    for (var i = 0; i < BUILDS.length; ++i)
        if (BUILDS[i].name === name) return BUILDS[i]
    return null
}

// --- what a crowd costs --------------------------------------------------------

// Boxes per character at each detail tier, which is very nearly its draw
// calls: measured on the crowd bench, and the number that carries from one
// machine to another where a millisecond does not. Minimal saves one box over
// Low; High adds the twenty boxes of fingers and the waist joint's split
// trunk is one box at every tier.
var BOXES = { minimal: 21, low: 22, high: 44 }

function expectedDraws(count, tier) {
    var per = BOXES[tier]
    return per === undefined ? 0 : per * Math.max(0, count)
}

// Draw calls the characters account for, per character, once the scene's own
// draws (floor, props) are taken off the top.
function drawsPerCharacter(draws, baseline, count) {
    if (!(count > 0)) return 0
    return Math.max(0, draws - baseline) / count
}
