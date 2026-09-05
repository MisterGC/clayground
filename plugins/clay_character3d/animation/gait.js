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
    // How much of the trunk's bend is a CURVE rather than a tilt: the angle
    // between belly and chest, positive rounding the back forward, negative
    // arching it and lifting the chest. Differential on purpose - it changes
    // the shape of the spine without moving where the head ends up, which is
    // lean's job. A slump is lean AND spineCurve; a plank is lean alone.
    spineCurve:{ kind: "add", neutral: 0, min: -25, max: 30 },
    headPitch: { kind: "add", neutral: 0, min: -40, max: 40 },
    armSwing:  { kind: "mul", neutral: 1, min: 0,   max: 2 },
    armForward:{ kind: "add", neutral: 0, min: -30, max: 60 },
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
    // Happy is the arms: the bounce is there but it is the big swing that
    // says "I am so happy" - the arms go well past the hips both ways. The
    // chest is open, so the spine arches rather than rounds.
    happy: { tempo: 1.12, bounce: 0.075, armSwing: 1.7, elbow: 6, kneeLift: 1.25, headPitch: -8, lean: -2, spineCurve: -7 },
    // Sad is the back. The lean alone made a plank tip; the curve is what
    // makes it read as weight - the belly settles back, the chest rounds
    // forward over it, and the head hangs off the end of that curve.
    sad:   { tempo: 0.82, stride: 0.82, armSwing: 0.45, kneeLift: 0.75, headPitch: 20, lean: 7, elbow: 4, spineCurve: 14 },
    // Angry is SHORT, HARD steps with the arms held in - not a big swing.
    // The first version swung the arms half again as far as a walk and
    // carried them 22 degrees forward on top, which came out as a lope with
    // the forearms flapping across the chest; a stride longer than a neutral
    // walk made it worse, because ground covered easily is the opposite of
    // what anger looks like. So: quicker and shorter (tempo up, stride down),
    // the knees stamping, the shoulders hunched over a forward head - the
    // bull, not the strider.
    //
    // The arms are the part that had to be measured on a sheet rather than
    // reasoned about. Sliding the whole swing 22 degrees forward put both
    // upper arms ahead of the body at once and left them barely alternating -
    // a sleepwalker from every angle. Folding the elbow to 80 instead put
    // both forearms out horizontally, which is the same silhouette by another
    // route, and it left the arms swinging at the hips with no attitude at
    // all. What works is a NORMAL swing with a hard bend and almost no
    // forward bias: the upper arms still pass each other, so the swing reads
    // head-on as well as in profile, and 65 degrees of elbow carries the
    // fists from in front of the hip to in front of the chest and back -
    // which is the pumping the forward bias was reaching for and could not
    // make without folding the silhouette flat.
    angry: { tempo: 1.22, stride: 0.92, lean: 11, spineCurve: 6, armSwing: 1.0, elbow: 55,
             armForward: 4, kneeLift: 1.25, headPitch: 7, rock: 4, bounce: 0.015 }
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
    // A small child stands with the belly forward and the back arched, not
    // slumped - the spine curve is negative for the same reason the lean is.
    child:     { tempo: 1.22, stride: 0.92, kneeLift: 1.3, bounce: 0.025, armSwing: 1.2,
                 lean: -3, spineCurve: -8 },
    // Deliberately further from `sad` than the numbers first were: on a cycle
    // sheet the two came out as the same slouch, and the thing that separates
    // them is not more sadness, it is the feet. Age is short careful steps
    // that barely leave the ground.
    elderly:   { tempo: 0.72, stride: 0.60, kneeLift: 0.45, lean: 8, headPitch: 15, elbow: 18,
                 armSwing: 0.45, spineCurve: 18 },
    feminine:  { sway: 9, armSwing: 0.8, elbow: 6, stride: 0.95, spineCurve: -3 },
    masculine: { rock: 2, armSwing: 1.15, stride: 1.05, spineCurve: 2 },
    // Weight in front has to be counterbalanced behind: a heavy walker leans
    // BACK and leads with the belly. The old forward 2 degrees fought the
    // gut it was supposed to be carrying.
    heavy:     { tempo: 0.82, stride: 0.86, rock: 6, elbow: 4, kneeLift: 0.9, lean: -3, spineCurve: -3 },
    light:     { tempo: 1.06, bounce: 0.01 },
    athletic:  { lean: 3, armSwing: 1.15, tempo: 1.05, elbow: 8, spineCurve: -4 },
    soft:      { lean: 4, headPitch: 4, armSwing: 0.85, spineCurve: 6 }
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
    sneak:    { tempo: 0.7, stride: 0.7, kneeLift: 1.5, lean: 12, headPitch: 8, elbow: 26,
                armSwing: 0.5, spineCurve: 12 },
    // Proud is the chest, and the chest is a NEGATIVE curve: the back arches,
    // the ribs come up and forward, the shoulders go back. A backward lean on
    // its own only makes a figure recline.
    proud:    { tempo: 0.92, stride: 1.08, lean: -7, headPitch: -9, armSwing: 1.25, elbow: 8,
                spineCurve: -12 },
    march:    { kneeLift: 1.7, armSwing: 1.5, lean: -3, bounce: 0.015, elbow: -10, spineCurve: -6 }
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

// How a trunk bend is shared between the two spine segments.
//
// BELLY_SHARE is the belly's part of the total tilt; the chest takes the rest
// on top of it, so the head still ends up tipped by exactly `lean` and the
// foot placement the speed is derived from is untouched. The chest gets the
// larger share because that is where a slump reads - the upper back is what
// an audience sees round.
//
// AUTO_CURVE turns part of a FACTOR lean into curvature on its own: a
// character asked to lean 8 degrees bends over its spine instead of tipping
// like a plank, which is the whole reason the trunk was split.
//
// A BASE lean is different and gets none of this. A run's 12 degrees is a
// sprinter's straight line from the ankles: the whole figure tips, legs
// included, and the waist joint stays shut. It goes on the belly alone, with
// nothing at the joint - the first version shared it like a factor lean and
// put a seven-degree kink in the middle of every runner's back.
var BELLY_SHARE = 0.4
var AUTO_CURVE = 0.5

// The two spine angles. `baseLean` tips the trunk rigidly; `waistLean` is
// shared between the segments; `curve` is differential - it bends the belly
// back by as much as it bends the chest forward, so it changes the shape of
// the trunk without moving the head. belly + chest is always
// baseLean + waistLean.
function spineFrom(baseLean, waistLean, curve) {
    var half = 0.5 * (curve + AUTO_CURVE * waistLean)
    return {
        belly: clamp(baseLean + waistLean * BELLY_SHARE - half, -45, 45),
        chest: clamp(waistLean * (1 - BELLY_SHARE) + half, -45, 45)
    }
}

// The table a cycle animates from. Joint limits here are geometric: whatever
// the factors say, a knee does not pass 150 degrees and a hip does not swing
// past 80, and a cycle shorter than a quarter second or longer than two is a
// twitch or a freeze, not a walk.
function derive(baseName, factors) {
    var b = BASES[baseName] || BASES.walk
    var f = factors || neutral()
    function get(k) { var v = Number(f[k]); return isFinite(v) ? v : FACTORS[k].neutral }
    var kneeK = get("kneeLift")
    // The trunk, solved once: the total tilt, the share of it that pivots at
    // the waist, and the curve the two segments take.
    var lean = clamp(b.lean + get("lean"), -30, 40)
    var waistLean = clamp(get("lean"), -30, 30)
    var curve = clamp(get("spineCurve"), -25, 30)
    var spine = spineFrom(b.lean, waistLean, curve)
    return {
        base: BASES[baseName] ? baseName : "walk",
        cycleMs: clamp(b.cycleMs / get("tempo"), 250, 2000),
        hipFwd: clamp(b.hipFwd * get("stride"), 0, 80),
        hipBack: clamp(b.hipBack * get("stride"), 0, 80),
        kneeLift: clamp(b.kneeLift * kneeK, 0, 150),
        kneeExtend: b.kneeExtend,
        footUp: clamp(b.footUp * kneeK, 0, 60),
        footDown: clamp(b.footDown * kneeK, 0, 60),
        // armForward shifts the whole swing ahead of the body: more reach in
        // front, less behind, the same amplitude. A negative armBack means the
        // arm never gets behind the hip at all.
        armFwd: clamp(b.armFwd * get("armSwing") + get("armForward"), 0, 110),
        armBack: clamp(b.armBack * get("armSwing") - get("armForward"), -60, 90),
        elbow: clamp(b.elbow + get("elbow"), 0, 140),
        lean: lean,
        // The factor's share of the lean pivots at the WAIST: the hip counters
        // it so the legs stay planted and only chest, head and arms tip. The
        // base's own lean (a run's 12) stays whole-body - a sprinter leans
        // with everything, a slump bends. Without this a sad character rotates
        // like a plank about its waist and looks about to fall on its face.
        waistLean: waistLean,
        // The trunk is two segments on a waist joint, so the tilt above is
        // reported as the pair of angles the segments actually take. Their
        // sum is `lean`; their difference is how round the back is.
        bellyLean: spine.belly,
        chestLean: spine.chest,
        spineCurve: curve,
        // What the hip does about all that. The pelvis hangs off the BELLY, so
        // it only ever sees the belly's share of the tilt, and it gives back
        // exactly enough of it to leave the legs where the base asked for
        // them: standing upright under a factor lean, tipped with the whole
        // figure under a run's.
        hipLean: b.lean - spine.belly,
        headPitch: clamp(get("headPitch"), -40, 40),
        bounce: clamp(get("bounce"), 0, 0.1),
        sway: clamp(get("sway"), 0, 20),
        rock: clamp(get("rock"), 0, 15)
    }
}

// Where the ankle is, along the walking direction, for a hip angle and a
// knee angle - forward kinematics of the two-segment leg. Positive z is
// forward; a forward hip is negative, a knee bends the shin back.
function ankleZ(hip, knee, upper, lower) {
    var rad = Math.PI / 180
    return -upper * Math.sin(hip * rad) - lower * Math.sin((hip + knee) * rad)
}

// How far the feet travel in one cycle, and the speed that keeps the ground
// moving under them. Measured on the PLANTED foot, knee included: over one
// step the stance leg goes from forward-and-nearly-straight to back-and-bent,
// and the ankle's travel between those two poses is what the body has to
// cover for the foot not to slide. The old cycles used the straight-leg
// arc, which over-reached the walk by a fifth and under-shot the run by a
// quarter - visible as feet skating - and the difference is the knee.
function strideLength(table, legHeight, upperRatio) {
    var r = (upperRatio === undefined || !isFinite(upperRatio)) ? 0.5 : upperRatio
    var upper = legHeight * r, lower = legHeight * (1 - r)
    var start = ankleZ(-table.hipFwd, table.kneeExtend, upper, lower)
    var end = ankleZ(table.hipBack, table.kneeLift, upper, lower)
    return Math.max(0, start - end) * 2
}

function speedFor(table, legHeight, upperRatio) {
    return strideLength(table, legHeight, upperRatio) / (table.cycleMs / 1000)
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
// have them. The hip is a child of the belly, so its pitch is the counter to
// the belly's bend and its yaw the sway. t in [0, 0.5) is the first phase (right leg swinging forward),
// [0.5, 1) the second; t = 1 is t = 0 again. Angles follow the joints' own
// conventions: positive x pitches forward and down, so a forward leg or arm is
// negative x. Legs and arms are {upper, lower, foot|hand}; torso, belly, chest,
// hip and head are [x, y, z]; lift is in leg heights. belly and chest are the
// two halves of the trunk on either side of the waist joint: their pitches sum
// to the table's lean and their difference is how round the back is.
function poseAt(table, t) {
    t = t - Math.floor(t)
    var second = t >= 0.5
    var raw = (second ? t - 0.5 : t) * 2
    var u = easeInOutQuad(raw)
    function mix(a, b) { return a + (b - a) * u }
    // The hips move LINEARLY: the planted foot has to travel under the body
    // at the body's own speed, and an eased hip parks it at both ends of the
    // step and rushes it through the middle - the feet skate either way.
    function mixHip(a, b) { return a + (b - a) * raw }

    // The leg that swings forward this phase, and the one that goes back.
    var fwd = {
        upper: mixHip(table.hipBack, -table.hipFwd),
        lower: mix(table.kneeLift, table.kneeExtend),
        foot: mix(table.footDown, -table.footUp)
    }
    var back = {
        upper: mixHip(-table.hipFwd, table.hipBack),
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
        hip: [table.hipLean, yaw, 0],
        // The trunk group carries no pitch of its own any more: the tilt
        // lives in the two spine segments below it, whose angles add up to
        // table.lean. Sway and rock stay here, where they turn and roll the
        // whole trunk over the planted leg.
        torso: [0, -yaw * 0.5, roll],
        belly: [table.bellyLean, 0, 0],
        chest: [table.chestLean, 0, 0],
        head: [table.headPitch, 0, 0],
        lift: table.bounce * liftAt(second ? (t - 0.5) * 2 : t * 2)
    }
}
