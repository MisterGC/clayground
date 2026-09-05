// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The gait model: what a walk or a run is made of, and how a body, a mood
// and an author's word change it.
//
// Deliberately Qt-free (.pragma library, no engine, no clock, no randomness)
// so `node gait.test.js` checks it in a second and the one claim that
// matters most - the all-neutral gait IS the walk and run the framework
// always had - is an exact assertion on numbers rather than a comparison of
// screenshots.
//
// Three ideas, in order:
//
//   1. A BASE is the cycle as it was authored: hip swing, knee lift, foot
//      angles, arm swing, elbow, lean, cycle length. Two of them, walk and
//      run, and their numbers are the ones WalkAnim and RunAnim carried
//      before this file existed.
//   2. A FACTOR VECTOR says how far from neutral a gait is, one number per
//      factor. Multiplicative factors (tempo, stride, ...) are 1 at neutral;
//      additive ones (lean, bounce, ...) are 0. Every source - a preset, the
//      build sliders, an emotion, the author's Gait object - produces one,
//      and compose() folds them: products multiply, sums add, clamped once
//      at the end. There is no override layer on purpose; "elderly, a fifth
//      quicker" is `preset: "elderly"` times `tempo: 1.2` and reads that way.
//   3. derive(base, factors) turns the two into the TABLE a cycle animates
//      from, and poseAt(table, t) replays the cycle at any phase without an
//      animation running - the cycle sheet is drawn from it.

.pragma library

// --- factors ------------------------------------------------------------------

// kind: "mul" factors scale a base amplitude, "add" factors offset one.
// The ranges are where a single factor is clamped after composition; the
// joint limits in derive() are the second, geometric, line of defence.
var FACTORS = {
    tempo:     { kind: "mul", neutral: 1, min: 0.4, max: 2.5 },
    stride:    { kind: "mul", neutral: 1, min: 0.3, max: 1.6 },
    bounce:    { kind: "add", neutral: 0, min: 0,   max: 0.1 },
    lean:      { kind: "add", neutral: 0, min: -30, max: 30 },
    headPitch: { kind: "add", neutral: 0, min: -40, max: 40 },
    armSwing:  { kind: "mul", neutral: 1, min: 0,   max: 2 },
    elbow:     { kind: "add", neutral: 0, min: -10, max: 80 },
    kneeLift:  { kind: "mul", neutral: 1, min: 0.3, max: 2 },
    sway:      { kind: "add", neutral: 0, min: 0,   max: 20 },
    rock:      { kind: "add", neutral: 0, min: 0,   max: 15 }
}

var FACTOR_NAMES = Object.keys(FACTORS)

function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v }

function neutral() {
    var f = {}
    for (var i = 0; i < FACTOR_NAMES.length; i++)
        f[FACTOR_NAMES[i]] = FACTORS[FACTOR_NAMES[i]].neutral
    return f
}

// A vector with only some factors set, pulled toward neutral by w (0 = neutral,
// 1 = as given). Used for the build zones, which fade in over a slider range.
function scaled(vec, w) {
    var out = {}
    for (var k in vec) {
        if (!FACTORS[k]) continue
        var n = FACTORS[k].neutral
        out[k] = n + (vec[k] - n) * w
    }
    return out
}

// Fold any number of partial vectors (null entries are skipped) into one
// complete, clamped vector.
function compose(layers) {
    var f = neutral()
    for (var i = 0; i < layers.length; i++) {
        var layer = layers[i]
        if (!layer) continue
        for (var k in layer) {
            var spec = FACTORS[k]
            if (!spec) continue
            var v = Number(layer[k])
            if (!isFinite(v)) continue
            f[k] = spec.kind === "mul" ? f[k] * v : f[k] + v
        }
    }
    for (var j = 0; j < FACTOR_NAMES.length; j++) {
        var name = FACTOR_NAMES[j]
        f[name] = clamp(f[name], FACTORS[name].min, FACTORS[name].max)
    }
    return f
}

// --- bases --------------------------------------------------------------------

// Angles in degrees, cycle in ms. These are the constants WalkAnim and RunAnim
// used to hold, with the ones they derived from each other written out:
// walk knee lift was 25 + 20 * ((25 + 20) / 45), run knee lift
// 70 + 40 * ((55 + 45) / 70), and so on. gait.test.js asserts these against
// the original formulas so a retyped digit cannot pass as the neutral gait.
var BASES = {
    walk: {
        hipFwd: 25, hipBack: 20,
        kneeLift: 45, kneeExtend: 15,
        footUp: 20, footDown: 25,
        armFwd: 15, armBack: 13.5,
        elbow: 10, lean: 0,
        cycleMs: 800
    },
    run: {
        hipFwd: 55, hipBack: 45,
        kneeLift: 70 + 40 * (100 / 70), kneeExtend: 10 + 5 * (100 / 70),
        footUp: 25, footDown: 35,
        armFwd: 55, armBack: 45,
        elbow: 70, lean: 12,
        cycleMs: 450
    }
}

// --- sources ------------------------------------------------------------------

// What each emotion the framework knows does to a walk. The numbers echo
// TalkGestureAnim's posture table (sad lean 9, angry 5, head 15/6) so the
// character that slumps while it talks sadly slumps the same way when it
// walks off; they are deliberately smaller than a preset can go, because an
// emotion is worn on top of a build, not instead of one.
var EMOTIONS = {
    happy: { tempo: 1.12, bounce: 0.04, armSwing: 1.25, kneeLift: 1.12, headPitch: -5, lean: -2 },
    sad:   { tempo: 0.82, stride: 0.82, armSwing: 0.55, kneeLift: 0.75, headPitch: 16, lean: 7, elbow: 4 },
    // The elbows bend only a little: with the walk's small arm swing a bent
    // forearm points straight ahead and reads as reaching, not as a fist
    // pumping. The swing is what carries the anger; the bend just closes it.
    angry: { tempo: 1.15, stride: 1.08, lean: 9, armSwing: 1.4, elbow: 18, kneeLift: 1.08, headPitch: 5, rock: 2 }
}

function canonicalEmotion(e) {
    e = ("" + (e === undefined || e === null ? "" : e)).toLowerCase()
    if (e === "joy") return "happy"
    if (e === "sadness") return "sad"
    if (e === "anger") return "angry"
    return EMOTIONS[e] ? e : ""
}

function emotionFactors(emotion) {
    var e = canonicalEmotion(emotion)
    return e === "" ? null : EMOTIONS[e]
}

// The two ends of the maturity slider, and the four build directions. Each is
// the FULL effect; buildFactors() fades them in over the slider's zone.
var BUILD = {
    child:     { tempo: 1.22, stride: 0.92, kneeLift: 1.3, bounce: 0.025, armSwing: 1.2 },
    elderly:   { tempo: 0.72, stride: 0.72, kneeLift: 0.6, lean: 8, headPitch: 12, elbow: 12, armSwing: 0.5 },
    feminine:  { sway: 9, armSwing: 0.8, elbow: 6, stride: 0.95 },
    masculine: { rock: 2, armSwing: 1.15, stride: 1.05 },
    heavy:     { tempo: 0.82, stride: 0.86, rock: 6, elbow: 4, kneeLift: 0.9, lean: 2 },
    light:     { tempo: 1.06, bounce: 0.01 },
    athletic:  { lean: 3, armSwing: 1.15, tempo: 1.05, elbow: 8 },
    soft:      { lean: 4, headPitch: 4, armSwing: 0.85 }
}

// build: { maturity, femininity, mass, muscle }, each 0..1, 0.5 = neutral.
// Zero effect at every default: maturity is neutral between 0.4 and 0.75
// (the proportion tables treat 1 as a full adult, so only the top quarter is
// read as elderly, for gait alone), the other three fade out linearly toward
// their centre.
function buildFactors(build) {
    if (!build) return null
    function num(v, d) { v = Number(v); return isFinite(v) ? v : d }
    var m = clamp(num(build.maturity, 0.5), 0, 1)
    var f = clamp(num(build.femininity, 0.5), 0, 1)
    var w = clamp(num(build.mass, 0.5), 0, 1)
    var u = clamp(num(build.muscle, 0.5), 0, 1)

    var layers = []
    var child = clamp((0.4 - m) / 0.4, 0, 1)
    var elderly = clamp((m - 0.75) / 0.25, 0, 1)
    if (child > 0) layers.push(scaled(BUILD.child, child))
    if (elderly > 0) layers.push(scaled(BUILD.elderly, elderly))

    var df = (f - 0.5) * 2
    if (df > 0) layers.push(scaled(BUILD.feminine, df))
    if (df < 0) layers.push(scaled(BUILD.masculine, -df))

    var dw = (w - 0.5) * 2
    if (dw > 0) layers.push(scaled(BUILD.heavy, dw))
    if (dw < 0) layers.push(scaled(BUILD.light, -dw))

    var du = (u - 0.5) * 2
    if (du > 0) layers.push(scaled(BUILD.athletic, du))
    if (du < 0) layers.push(scaled(BUILD.soft, -du))

    return layers.length === 0 ? null : compose(layers)
}

// Named gaits an author can ask for by word. The three emotional ones share
// their rows with EMOTIONS so setEmotion("sad") and preset "dejected" cannot
// drift apart; the build ones share theirs with BUILD for the same reason.
var PRESETS = {
    neutral:  {},
    cheerful: EMOTIONS.happy,
    dejected: EMOTIONS.sad,
    furious:  EMOTIONS.angry,
    elderly:  BUILD.elderly,
    toddler:  compose([BUILD.child, { tempo: 1.1 }]),
    heavy:    compose([BUILD.heavy, { rock: 2 }]),
    sneak:    { tempo: 0.7, stride: 0.7, kneeLift: 1.5, lean: 12, headPitch: 8, elbow: 26, armSwing: 0.5 },
    proud:    { tempo: 0.92, stride: 1.08, lean: -7, headPitch: -9, armSwing: 1.25, elbow: 8 },
    march:    { kneeLift: 1.7, armSwing: 1.5, lean: -3, bounce: 0.015, elbow: -10 }
}

var PRESET_NAMES = Object.keys(PRESETS)

function presetKnown(name) {
    return name === "" || name === undefined || name === null
        || Object.prototype.hasOwnProperty.call(PRESETS, "" + name)
}

function presetFactors(name) {
    if (name === "" || name === undefined || name === null) return null
    return PRESETS[name] || null
}

// --- derivation ---------------------------------------------------------------

// The table a cycle animates from. Joint limits here are geometric: whatever
// the factors say, a knee does not pass 150 degrees and a hip does not swing
// past 80, and a cycle shorter than a quarter second or longer than two is a
// twitch or a freeze, not a walk.
function derive(baseName, factors) {
    var b = BASES[baseName] || BASES.walk
    var f = factors || neutral()
    function get(k) { var v = Number(f[k]); return isFinite(v) ? v : FACTORS[k].neutral }
    var kneeK = get("kneeLift")
    return {
        base: BASES[baseName] ? baseName : "walk",
        cycleMs: clamp(b.cycleMs / get("tempo"), 250, 2000),
        hipFwd: clamp(b.hipFwd * get("stride"), 0, 80),
        hipBack: clamp(b.hipBack * get("stride"), 0, 80),
        kneeLift: clamp(b.kneeLift * kneeK, 0, 150),
        kneeExtend: b.kneeExtend,
        footUp: clamp(b.footUp * kneeK, 0, 60),
        footDown: clamp(b.footDown * kneeK, 0, 60),
        armFwd: clamp(b.armFwd * get("armSwing"), 0, 90),
        armBack: clamp(b.armBack * get("armSwing"), 0, 90),
        elbow: clamp(b.elbow + get("elbow"), 0, 140),
        lean: clamp(b.lean + get("lean"), -30, 40),
        // The factor's share of the lean pivots at the WAIST: the hip counters
        // it so the legs stay planted and only chest, head and arms tip. The
        // base's own lean (a run's 12) stays whole-body - a sprinter leans
        // with everything, a slump bends. Without this a sad character rotates
        // like a plank about its waist and looks about to fall on its face.
        waistLean: clamp(get("lean"), -30, 30),
        headPitch: clamp(get("headPitch"), -40, 40),
        bounce: clamp(get("bounce"), 0, 0.1),
        sway: clamp(get("sway"), 0, 20),
        rock: clamp(get("rock"), 0, 15)
    }
}

// How far the feet travel in one cycle, from the hip angles and the leg, and
// the speed that keeps the ground moving under them. Same formula the old
// cycles used, so movement stays foot-locked whatever the gait.
function strideLength(table, legHeight) {
    var rad = Math.PI / 180
    return legHeight * (Math.sin(table.hipFwd * rad) + Math.sin(table.hipBack * rad)) * 2
}

function speedFor(table, legHeight) {
    return strideLength(table, legHeight) / (table.cycleMs / 1000)
}

// --- the cycle, replayed -------------------------------------------------------

// Qt's Easing.InOutQuad, which every joint in the cycle eases with.
function easeInOutQuad(t) {
    return t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t)
}

// The lift within one step: up to the peak at mid-step and back, both halves
// eased. GaitCycleAnim animates exactly this shape; keep the two together.
function liftAt(u) {
    return u < 0.5 ? easeInOutQuad(u * 2) : 1 - easeInOutQuad((u - 0.5) * 2)
}

// Joint angles at phase t of the cycle, 0..1, as the cycle animation would
// have them. The hip is a child of the torso, so its pitch is the counter to
// the waist lean and its yaw the sway. t in [0, 0.5) is the first phase (right leg swinging forward),
// [0.5, 1) the second; t = 1 is t = 0 again. Angles follow the joints' own
// conventions: positive x pitches forward and down, so a forward leg or arm is
// negative x. Legs and arms are {upper, lower, foot|hand}; torso, hip and head
// are [x, y, z]; lift is in leg heights.
function poseAt(table, t) {
    t = t - Math.floor(t)
    var second = t >= 0.5
    var u = easeInOutQuad((second ? t - 0.5 : t) * 2)
    function mix(a, b) { return a + (b - a) * u }

    // The leg that swings forward this phase, and the one that goes back.
    var fwd = {
        upper: mix(table.hipBack, -table.hipFwd),
        lower: mix(table.kneeLift, table.kneeExtend),
        foot: mix(table.footDown, -table.footUp)
    }
    var back = {
        upper: mix(-table.hipFwd, table.hipBack),
        lower: mix(table.kneeExtend, table.kneeLift),
        foot: mix(-table.footUp, table.footDown)
    }
    // Arms oppose their leg: the arm on the forward leg's side goes back.
    var armBack = { upper: mix(-table.armFwd, table.armBack), lower: -table.elbow }
    var armFwd = { upper: mix(table.armBack, -table.armFwd), lower: -table.elbow }

    // Right leg forward means the right hip leads: a negative yaw brings the
    // +X side forward, so over the first phase the hip yaws from +sway to
    // -sway and back over the second; the torso counters by half. Weight is
    // on the planted (left) leg, so the body tips over it: a positive roll
    // takes the top of the torso toward -X, arriving as the step completes.
    var s = second ? -1 : 1
    var yaw = mix(table.sway * s, -table.sway * s)
    var roll = mix(-table.rock * s, table.rock * s)
    return {
        rightLeg: second ? back : fwd,
        leftLeg: second ? fwd : back,
        rightArm: second ? armFwd : armBack,
        leftArm: second ? armBack : armFwd,
        hip: [-table.waistLean, yaw, 0],
        torso: [table.lean, -yaw * 0.5, roll],
        head: [table.headPitch, 0, 0],
        lift: table.bounce * liftAt(second ? (t - 0.5) * 2 : t * 2)
    }
}
