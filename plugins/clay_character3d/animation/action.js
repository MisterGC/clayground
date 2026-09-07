// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The action model: what the arms do when the character is not walking and
// not holding a gesture - standing still, working at something, boxing.
//
// Qt-free on purpose (.pragma library, no engine, no clock, no randomness),
// for the same reason gait.js is: `node action.test.js` checks the poses in a
// second, and "the guard has both fists above the elbows" is then an exact
// assertion on numbers rather than an impression from a screenshot.
//
// One idea, borrowed whole from gait.js: a BASE is the action as it was
// authored, derive() turns a base and its options into the TABLE, and
// poseAt(table, t) replays the cycle at any phase with nothing running. The
// difference is that here poseAt is not a second copy of the animation -
// ActionCycleAnim animates one number, the phase, and writes what poseAt
// answers. So the strip of stills in bench/GestureSheetSandbox.qml is drawn
// from the same function the shipped cycle plays, and cannot drift from it.
//
// SIGNS, throughout, are the joints' own conventions:
//   * upper/lower arm and leg x: negative pitches the limb FORWARD.
//   * upper arm z: positive carries the arm OUT from the ribs on the +X
//     (right) side; poses here are written unsigned and mirrored at use.
//   * hand y: the wrist roll about the forearm. Positive on the right arm
//     turns the palm in to face the body - Character::handRestRoll's axis.
//   * head x: positive looks DOWN.

.pragma library

// --- standing still -----------------------------------------------------------

// What a body holds when nothing else is driving it. It used to be sixteen
// zeros, and sixteen zeros is a shop dummy: arms dead straight, glued to the
// ribs, dead-parallel with the trunk. Three small angles is all it takes for
// the same figure to read as a person standing there - and they are small on
// purpose, because this pose is also the baseline every gesture is entered
// from and released back to.
var REST = {
    // The upper arms hang clear of the ribs. Without this the silhouette has
    // no gap between arm and torso at all, so from the front the figure is one
    // block with a head on it.
    armOut: 5,
    // And a hair forward of the shoulder seam: an arm hanging dead vertical
    // reads as hung rather than held.
    armForward: 4,
    // Nobody stands with a locked elbow.
    elbow: 8,
    // Scales Character::handRestRoll, the quarter turn that brings the palms
    // in to face the body.
    handRoll: 1,
    // What the fingers do at rest. DetailedHand's own default, named here so
    // the rest pose is one thing in one place.
    hand: "relax"
}

// The rest pose in the shape poseAt() answers with, so an animator can ease
// back to standing without knowing which of the two it is holding.
function restPose() {
    return {
        rightArm: arm(-REST.armForward, 0, REST.armOut, -REST.elbow, 0, REST.handRoll, 1),
        leftArm: arm(-REST.armForward, 0, REST.armOut, -REST.elbow, 0, REST.handRoll, -1),
        rightLeg: leg(0, 0, 0),
        leftLeg: leg(0, 0, 0),
        hip: [0, 0, 0],
        torso: [0, 0, 0],
        belly: [0, 0, 0],
        chest: [0, 0, 0],
        head: [0, 0, 0],
        hand: REST.hand
    }
}

// --- the bases ----------------------------------------------------------------

var BASES = {

    // Boxing. What was here before was a guard with the elbows winged out at
    // shoulder height and the fists a forearm's length in front of the chest,
    // which is not a guard - and the hands were never told to close, so the
    // whole thing read as clawing rather than as boxing. Three things fix it
    // and all three are in this table: elbows DOWN and in against the ribs,
    // forearms near vertical so the fists sit at cheek height, and a stance
    // that is bladed rather than square.
    fight: {
        // The guard. Upper arm barely forward of hanging and barely out from
        // the ribs: a boxer's elbows protect the body, and an elbow that has
        // left the ribs is the single thing that makes a guard read as a
        // shrug instead.
        guardUpper: 20,
        guardOut: 8,
        // Brought in across the chest, so the two fists are in front of the
        // face rather than beside it.
        guardIn: 16,
        // Forearm angle at the elbow. 20 + 138 = 158 degrees forward of
        // hanging, which is 22 short of straight up: the fist lands about a
        // shoulder's height, a little in front of the face.
        guardElbow: 138,
        // The palms face each other, which is what turns two blocks on the
        // ends of two arms into a guard. Scales handRestRoll.
        guardRoll: 0.9,
        // A guard's wrists are cocked slightly forward, knuckles leading.
        guardWrist: -8,

        // The punch. The arm comes out nearly straight and level, and the
        // fist turns over on the way: a straight thrown with the palm still
        // facing in is a slap.
        punchUpper: 78,
        punchElbow: 12,
        punchOut: 2,
        punchRoll: 0.1,
        punchWrist: 0,

        // How the trunk drives it. Shared: the group turns the hips and the
        // legs with it, the chest turns further on the waist joint, so the
        // shoulders arrive ahead of the hips and the stance stays planted.
        twist: 20,
        hipShare: 0.4,
        chestShare: 0.6,

        // The stance. A bladed body - lead shoulder toward the opponent - is
        // most of what says "boxing" from any angle at all, and it costs one
        // yaw on the trunk group, which carries the legs with it.
        blade: 18,
        // Chest rolled forward over the guard, chin behind it. Both stay
        // SMALL: the chest lean already tips the head, and the two together
        // sink it into the shoulders - a boxer looking at its own feet.
        guardLean: 6,
        headPitch: 3,
        // The stance. Both knees bent, one foot forward of the other, and the
        // feet apart across the line of the shoulders - the width is what
        // stops a bladed stance reading as two crossed legs from any angle
        // other than dead side-on.
        leadKnee: 18,
        rearKnee: 14,
        leadHip: 7,
        rearHip: 5,
        stanceWide: 6,

        cycleMs: 1400
    },

    // Working at a bench, a desk, a console - "doing something". What was
    // here before held a single pose with the upper arms 45-65 degrees
    // forward, so the hands hovered at chest height and the only motion in
    // the whole cycle was the elbows rolling a few degrees: a figure holding
    // its arms up, not a figure working. The arms come DOWN here - the
    // forearms sit about level, which puts the hands over a waist-high
    // surface - and the stroke is big enough to see from across a room.
    use: {
        // Where the arms are between strokes. The upper arm hangs close to
        // the ribs and the elbow does the reaching, so the forearm comes out
        // about level and the hands sit over a waist-high surface: the sum of
        // the two, 16 + 64, is how far forward of hanging the forearm is.
        upper: 16,
        out: 13,
        elbow: 64,
        wrist: 8,

        // The stroke: how far the hand travels, per joint. Mostly the ELBOW,
        // which drops the hand onto the work and lifts it off again; the
        // upper arm follows a little and the arm sweeps a little across the
        // body, so no two moments of the cycle have the hand on the same
        // spot. Together they carry the hand about a third of a forearm,
        // which is what makes this read as work rather than as a tremor -
        // the cycle this replaced moved it by nothing at all.
        strokeUpper: 10,
        strokeElbow: 38,
        strokeYaw: 9,
        strokeWrist: 20,

        // Leaning over it. Split between the two spine segments so the back
        // ROUNDS rather than tipping as one board; the hip gives the belly's
        // share straight back so the legs stay upright.
        lean: 12,
        spineCurve: 8,
        headPitch: 18,

        cycleMs: 1300
    }
}

var BASE_NAMES = Object.keys(BASES)

function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v }

function known(name) { return BASES[name] !== undefined }

// --- deriving a table ---------------------------------------------------------

// \a opts is what the animator was configured with: {intensity} for the
// fight, {intensity, workHeight} for the use. Everything is folded in here,
// so poseAt() only ever reads finished numbers.
function derive(name, opts) {
    var b = BASES[name]
    if (b === undefined)
        return derive("use", opts)
    opts = opts || {}
    var intensity = opts.intensity === undefined ? 0.5 : clamp(opts.intensity, 0, 1)

    if (name === "fight") {
        return {
            name: "fight",
            guardUpper: b.guardUpper,
            guardOut: b.guardOut + intensity * 3,
            guardIn: b.guardIn,
            // A harder guard is a tighter one: the fists come up.
            guardElbow: b.guardElbow + intensity * 8,
            guardRoll: b.guardRoll,
            guardWrist: b.guardWrist,
            punchUpper: b.punchUpper + intensity * 8,
            punchElbow: b.punchElbow,
            punchOut: b.punchOut,
            punchRoll: b.punchRoll,
            punchWrist: b.punchWrist,
            hipTwist: b.twist * b.hipShare * (0.6 + intensity * 0.8),
            chestTwist: b.twist * b.chestShare * (0.6 + intensity * 0.8),
            blade: b.blade,
            guardLean: b.guardLean,
            headPitch: b.headPitch,
            leadKnee: b.leadKnee,
            rearKnee: b.rearKnee,
            leadHip: b.leadHip,
            rearHip: b.rearHip,
            stanceWide: b.stanceWide,
            // Aggression is speed here, not reach: the angles above are what
            // a guard and a straight ARE, and a harder one is a faster one.
            cycleMs: Math.round(b.cycleMs / (0.75 + intensity * 0.5)),
            hand: "fist"
        }
    }

    // workHeight 0 is waist, 1 is shoulder. It lifts the whole arm and closes
    // the elbow rather than only tilting the forearm, so the hands arrive at
    // the surface instead of over it.
    var h = opts.workHeight === undefined ? 0.35 : clamp(opts.workHeight, 0, 1)
    return {
        name: "use",
        upper: b.upper + h * 30,
        out: b.out,
        elbow: b.elbow - h * 6,
        wrist: b.wrist,
        strokeUpper: b.strokeUpper * (0.7 + intensity * 0.6),
        strokeElbow: b.strokeElbow * (0.7 + intensity * 0.6),
        strokeYaw: b.strokeYaw * (0.7 + intensity * 0.6),
        strokeWrist: b.strokeWrist * (0.7 + intensity * 0.6),
        // Reaching high is standing up: the lean goes as the work rises.
        lean: b.lean * (1 - h * 0.7),
        spineCurve: b.spineCurve * (1 - h * 0.7),
        headPitch: b.headPitch * (1 - h * 0.6),
        cycleMs: Math.round(b.cycleMs / (0.7 + intensity * 0.6)),
        hand: "relax"
    }
}

// --- shaping ------------------------------------------------------------------

function easeInOutQuad(u) {
    return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2
}

function easeOutCubic(u) { return 1 - Math.pow(1 - u, 3) }

// A ramp from 0 to 1 across [a, b), flat outside it.
function ramp(u, a, b) {
    if (u <= a) return 0
    if (u >= b) return 1
    return (u - a) / (b - a)
}

// The shape of one punch over its own half of the cycle, 0 in the guard and 1
// at full extension. Not a sine and not a triangle: a punch SNAPS out, sits at
// the end of its reach for barely a moment and comes back slower than it went,
// and then there is a gap before the other hand goes. A symmetric curve here
// is the metronome that made the old loop read as two arms taking turns.
function punchAt(u) {
    if (u < 0.10) return 0
    if (u < 0.32) return easeOutCubic(ramp(u, 0.10, 0.32))
    if (u < 0.42) return 1
    if (u < 0.74) return 1 - easeInOutQuad(ramp(u, 0.42, 0.74))
    return 0
}

// The shape of one working stroke: out and back, both halves eased, over the
// whole of its own cycle. Unlike the punch this one never rests - work is
// continuous, and a pause in it reads as the character stopping.
function strokeAt(u) {
    u = u - Math.floor(u)
    return u < 0.5 ? easeInOutQuad(u * 2) : 1 - easeInOutQuad((u - 0.5) * 2)
}

// --- the pose -----------------------------------------------------------------

// One arm, in the shape poseAt answers with. \a side is 1 for the right arm
// and -1 for the left: `out` and `roll` are the two angles whose sign means
// "away from the body" rather than a direction in space, and `yaw` swings the
// arm across the chest, so all three are mirrored here and nowhere else.
function arm(pitch, yaw, out, elbow, wrist, roll, side) {
    return {
        upper: [pitch, side * yaw, side * out],
        lower: [elbow, 0, 0],
        hand: [wrist, side * roll * 90, 0]
    }
}

// \a out carries the whole leg away from the body's centre line, signed by
// \a side the way an arm's is: it is what puts a stance's feet apart.
function leg(upper, lower, foot, out, side) {
    return {
        upper: [upper, 0, (out === undefined ? 0 : out) * (side === undefined ? 1 : side)],
        lower: [lower, 0, 0],
        foot: [foot, 0, 0]
    }
}

// The pose \a table holds at phase \a t of its cycle, 0..1. Pure: the same
// answer the running cycle gives at that moment, which is what lets the sheet
// be drawn from it.
//
// The wrist roll comes back as a FRACTION of a quarter turn rather than in
// degrees, because the degrees belong to the character (handRestRoll) and not
// to the action. Whoever applies the pose multiplies.
function poseAt(table, t) {
    return table.name === "fight" ? fightAt(table, t) : useAt(table, t)
}

function fightAt(table, t) {
    t = t - Math.floor(t)
    // The right hand goes first, the left second. `lead` is the arm throwing
    // this half of the cycle.
    var right = t < 0.5
    var u = right ? t * 2 : (t - 0.5) * 2
    var p = punchAt(u)

    // The throwing arm, from the guard to full extension.
    var thrown = arm(-(table.guardUpper + (table.punchUpper - table.guardUpper) * p),
                     table.guardIn * (1 - p),
                     table.guardOut + (table.punchOut - table.guardOut) * p,
                     -(table.guardElbow + (table.punchElbow - table.guardElbow) * p),
                     table.guardWrist + (table.punchWrist - table.guardWrist) * p,
                     table.guardRoll + (table.punchRoll - table.guardRoll) * p,
                     right ? 1 : -1)
    var held = arm(-table.guardUpper, table.guardIn, table.guardOut,
                   -table.guardElbow, table.guardWrist, table.guardRoll,
                   right ? -1 : 1)

    // The trunk turns INTO the punch: the +X shoulder comes forward for a
    // right hand, so the yaw is negative there (a negative yaw brings the +X
    // side toward +Z, which is the way the character faces).
    var s = right ? -1 : 1
    var twist = p * s

    return {
        rightArm: right ? thrown : held,
        leftArm: right ? held : thrown,
        // The stance, bladed and staggered. The lead (left, -X) leg is
        // forward, so its hip is negative.
        rightLeg: leg(table.rearHip, table.rearKnee, 0, table.stanceWide, 1),
        leftLeg: leg(-table.leadHip, table.leadKnee, 0, table.stanceWide, -1),
        hip: [0, 0, 0],
        // The blade lives on the trunk group, which carries the hips and the
        // legs with it - which is exactly what a stance is.
        torso: [0, table.blade + table.hipTwist * twist, 0],
        belly: [0, 0, 0],
        chest: [table.guardLean, table.chestTwist * twist, 0],
        // The chin follows the shoulders round, and stays tucked.
        head: [table.headPitch, -table.chestTwist * twist * 0.5, 0],
        hand: table.hand
    }
}

function useAt(table, t) {
    t = t - Math.floor(t)
    // Half a cycle apart: one hand is reaching while the other comes back,
    // which is what makes two arms read as work rather than as calisthenics.
    var r = strokeAt(t)
    var l = strokeAt(t + 0.5)

    function side(s, sign) {
        return arm(-(table.upper + table.strokeUpper * s),
                   table.strokeYaw * (s - 0.5) * 2,
                   table.out,
                   -(table.elbow - table.strokeElbow * s),
                   table.wrist - table.strokeWrist * s,
                   // The palms stay turned toward each other over the work.
                   0.55,
                   sign)
    }

    var lean = table.lean
    var curve = table.spineCurve
    var belly = lean * 0.4 - curve * 0.5
    var chest = lean * 0.6 + curve * 0.5

    return {
        rightArm: side(r, 1),
        leftArm: side(l, -1),
        rightLeg: leg(0, 0, 0),
        leftLeg: leg(0, 0, 0),
        // The pelvis gives the belly's bend straight back, so the legs stay
        // upright under a rounded back.
        hip: [-belly, 0, 0],
        torso: [0, 0, 0],
        belly: [belly, 0, 0],
        chest: [chest, 0, 0],
        // The head goes with the working hand, a little.
        head: [table.headPitch, (r - l) * 4, 0],
        hand: table.hand
    }
}
