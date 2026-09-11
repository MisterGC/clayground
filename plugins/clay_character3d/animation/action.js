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
// answers. So the frozen columns of the character lab's gesture sheet
// (labs/kits/character/GestureSheet.qml) are drawn from the same function the
// shipped cycle plays, and cannot drift from it.
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
        lift: 0,
        hand: REST.hand
    }
}

// --- the bases ----------------------------------------------------------------

var BASES = {

    // Boxing. The guard is the whole of it: fists at the cheeks, elbows down
    // against the ribs, the body bladed and staggered, and a bounce that never
    // stops. It is an amateur's boxing on purpose - a wider stance, a bigger
    // bob, a straight that overreaches a touch - but every one of the things
    // that say "guarding" is kept exactly: both fists above both elbows, both
    // elbows below the shoulders and inside the line of the ribs, and the
    // hand that is not punching welded to the cheek.
    //
    // Orthodox: the LEFT is the lead, so the left jabs and the right crosses.
    // One cycle is jab, jab, cross - short, short, LONG - and then the guard
    // with its bounce, which is the rhythm the eye files as boxing rather
    // than as two arms taking turns.
    //
    // Numbers marked "off the brief" come from a coaching-and-animation
    // survey of the orthodox stance; the rest were dialled in at the action
    // scene of the character lab (labs/kits/character/ActionStage.qml).
    fight: {
        // The guard, per arm. The lead hand sits further out and a little
        // lower than the rear, which is tucked against the jaw - a guard
        // whose two fists are a mirror pair reads as a pose, and one whose
        // two are different reads as a person. Upper arms nearly hanging:
        // the forearm does the lifting, so the elbow stays down.
        leadUpper: 34,
        leadOut: 12,
        leadIn: 22,
        leadElbow: 132,
        leadRoll: 0.8,
        // The rear upper arm comes well forward before it is turned in:
        // turned in from nearly hanging, the elbow swings across INSIDE the
        // chest. Forward first, the elbow crosses in front of it.
        rearUpper: 46,
        rearOut: 3,
        rearIn: 40,
        rearElbow: 136,
        rearRoll: 0.95,
        // Wrists straight: a broken wrist is a slap waiting to happen, and
        // the brief has it at zero either way.
        guardWrist: 0,

        // The punch at full extension: the arm comes out nearly straight
        // and level, and the fist turns over on the way - a straight thrown
        // with the palm still facing in is a slap.
        punchUpper: 90,
        punchElbow: 14,
        punchOut: 4,
        punchRoll: 0.1,
        punchWrist: 0,
        // A jab is a shorter thing than a cross: it does not go all the way,
        // and the trunk barely turns for it.
        jabReach: 0.92,
        // The lead shoulder is already round toward the opponent, so a jab
        // straight out of it crosses the centre line; this swings it back
        // out to land where the cross lands. Measured at the bench.
        jabYaw: 20,

        // How the trunk drives the two punches. The jab barely turns the
        // body; the cross turns the hips a third of a turn and the shoulders
        // further, so the shoulders arrive ahead of the hips.
        jabHip: 5,
        jabChest: 9,
        crossHip: 26,
        crossChest: 32,
        // An extra lean into the cross - the amateur's overcommit.
        crossLean: 6,

        // The stance. A bladed body - lead shoulder toward the opponent - is
        // most of what says "boxing" from any angle, and the brief puts it at
        // 30-40 off square. The whole trunk group turns, legs included.
        blade: 30,
        // Chest rolled forward over the guard, chin down and looking through
        // the eyebrows. Both stay under twenty: the two add up on the head.
        guardLean: 7,
        headPitch: 10,
        // What fraction of the blade the head turns back, so the face looks
        // at the opponent rather than where the feet point.
        headTurn: 0.6,
        // Feet a shoulder's width apart front to back and a little more than
        // one across, both knees bent, the rear heel off the floor. The
        // stagger is the single thing the old stance lacked - its feet were
        // a third of this apart and read as a man standing slightly askew.
        leadHip: 20,
        rearHip: 14,
        leadKnee: 18,
        rearKnee: 16,
        stanceWide: 9,
        rearHeel: 24,
        // The rear foot turns on its ball as the cross goes through.
        crossPivot: 40,

        // The bounce, in leg heights, and the knee that goes with it. Three
        // per cycle so it loops, biased DOWN: a boxer sits at the top of the
        // range and dips, which is the opposite of a hop.
        bob: 0.05,
        bobKnee: 5,
        bobs: 3,
        // The weave, once per cycle: the shoulders roll a little around the
        // blade, the head follows late, the fists stay locked to the face.
        weave: 4,
        sway: 2.5,

        // The rhythm, as fractions of the cycle: where each punch starts and
        // ends. The second jab starts from a guard the first never quite got
        // back to, which is what makes a double jab read as one beat; the
        // gap before the cross is the weight rocking back to load it.
        jab1: [0.00, 0.20],
        jab2: [0.20, 0.38],
        cross: [0.45, 0.82],

        cycleMs: 1700
    },

    // Working at a bench, a desk, a shelf - "doing something". Generic on
    // purpose: it has to pass for cooking, tinkering, sorting and typing
    // alike, so it is built from what those share rather than from any one
    // of them - and what they share is not a stroke, it is a RHYTHM. A cycle
    // here is four beats: the lead hand reaches for something, both hands
    // work at it, the lead hand presses or places it, and the body settles
    // and glances up before the next. The cycle this replaced was one
    // symmetric stroke on two arms half a cycle apart, and a metronome does
    // not read as work however big its swing.
    //
    // Three things off the brief are load-bearing: the two hands are never
    // level and never mirrored (the lead sits ahead and above, the off hand
    // moves less and out of step by four tenths of a cycle rather than
    // half); the head does not simply lag the hands, it LEADS the reach and
    // lags the press; and the hands stay inside the torso's width and
    // within a forearm and a half of the chest, past which the pose stops
    // being work and becomes offering.
    use: {
        // The posture, keyed on where the work is: [waist, chest, head
        // height]. The elbow peaks in the middle - a counter is worked with
        // the forearms level - and the back straightens then arches as the
        // work rises, the head coming up with it.
        //
        // These are NOT the brief's shoulder and elbow angles. The brief's
        // put the hands a chest too high on this rig, whose forearm is the
        // upper arm's length and whose palm hangs below the wrist; they are
        // solved from where the hand has to LAND - fingertips on a surface
        // at the waist, the forearms angled up to a counter, the hands at
        // the face for a shelf - with the elbow kept low and behind them so
        // the hands stay within about six tenths of the arm's reach.
        upper: [12, 20, 70],
        out: [12, 14, 20],
        elbow: [76, 110, 100],
        // Palms turn down over a table and toward each other on a shelf:
        // a fraction of handRestRoll's quarter turn, 0 palm-down with the
        // forearm level.
        roll: [0.25, 0.45, 0.65],
        wrist: [-10, -5, -15],
        lean: [14, 6, -4],
        curve: [6, 3, -5],
        headPitch: [28, 14, -12],
        knee: [7, 5, 10],
        // The hands come in toward the centre line. This is the yaw for a
        // figure whose body was never given (see derive); given a body, the
        // yaw is solved so the two hands end up handGap hand-widths apart
        // whatever the shoulders measure - a fixed angle crossed a thin
        // figure's hands and left a broad one's a forearm apart.
        yawIn: 36,
        handGap: 0.6,
        // The lead (right) hand sits ahead of and above the off hand, always.
        leadAhead: 5,
        leadUp: 6,

        // The four beats, as fractions of the cycle.
        reach: [0.00, 0.22],
        work: [0.22, 0.62],
        press: [0.62, 0.82],
        settle: [0.82, 1.00],

        // REACH: the lead hand goes out and to the side for something,
        // most of a forearm; the shoulders turn with it and the head gets
        // there first.
        reachUpper: 26,
        reachElbow: 38,
        reachYaw: -32,
        reachChest: 5,
        reachHead: 12,
        // WORK: micro-strokes at about two a second, mostly in the elbow,
        // with a flick of the wrist at the end of each. The off hand does
        // two thirds as much and lags by four tenths of a stroke.
        strokes: 3,
        strokeUpper: 5,
        strokeElbow: 18,
        strokeWrist: 14,
        offShare: 0.65,
        offPhase: 0.4,
        // PRESS: the lead hand comes down on the work, the chest leans
        // into it, and it holds there a moment.
        pressUpper: -6,
        pressElbow: 12,
        pressWrist: 14,
        pressLean: 4,
        // SETTLE: both hands ease back toward the body, the weight shifts,
        // the head comes up a little.
        settleUpper: -6,
        settleElbow: 8,
        glance: -8,

        // The body under it all: a slow rock of the chest, a turn at half
        // that rate, and the weight going from one foot to the other once a
        // cycle, off the beat so it never lands on a stroke.
        rock: 2.5,
        rockYaw: 1.5,
        shift: 2.5,

        cycleMs: 3000
    }
}

var BASE_NAMES = Object.keys(BASES)

function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v }

function known(name) { return BASES[name] !== undefined }

// --- deriving a table ---------------------------------------------------------

// \a opts is what the animator was configured with: {intensity} for the
// fight, {intensity, workHeight} for the use, and - when the caller has a
// body - {shoulderWidth, armLength, handWidth} in the body's own units, so
// the hands can be placed against the body rather than at an angle. All of
// it is folded in here, so poseAt() only ever reads finished numbers.
function derive(name, opts) {
    var b = BASES[name]
    if (b === undefined)
        return derive("use", opts)
    opts = opts || {}
    var intensity = opts.intensity === undefined ? 0.5 : clamp(opts.intensity, 0, 1)

    if (name === "fight") {
        var k = 0.6 + intensity * 0.8
        return {
            name: "fight",
            leadUpper: b.leadUpper,
            leadOut: b.leadOut + intensity * 2,
            leadIn: b.leadIn,
            // A harder guard is a tighter one: the fists come up.
            leadElbow: b.leadElbow + intensity * 6,
            leadRoll: b.leadRoll,
            rearUpper: b.rearUpper,
            rearOut: b.rearOut + intensity * 2,
            rearIn: b.rearIn,
            rearElbow: b.rearElbow + intensity * 4,
            rearRoll: b.rearRoll,
            guardWrist: b.guardWrist,
            // The overreach grows with the effort - an amateur throwing hard
            // throws past the target.
            punchUpper: b.punchUpper + intensity * 6,
            punchElbow: b.punchElbow,
            punchOut: b.punchOut,
            punchRoll: b.punchRoll,
            punchWrist: b.punchWrist,
            jabReach: b.jabReach,
            jabYaw: b.jabYaw,
            jabHip: b.jabHip * k,
            jabChest: b.jabChest * k,
            crossHip: b.crossHip * k,
            crossChest: b.crossChest * k,
            crossLean: b.crossLean * k,
            blade: b.blade,
            guardLean: b.guardLean,
            headPitch: b.headPitch,
            headTurn: b.headTurn,
            leadHip: b.leadHip,
            rearHip: b.rearHip,
            leadKnee: b.leadKnee,
            rearKnee: b.rearKnee,
            stanceWide: b.stanceWide,
            rearHeel: b.rearHeel,
            crossPivot: b.crossPivot,
            bob: b.bob * k,
            bobKnee: b.bobKnee * k,
            bobs: b.bobs,
            weave: b.weave * k,
            sway: b.sway * k,
            jab1: b.jab1,
            jab2: b.jab2,
            cross: b.cross,
            // Aggression is speed here, not reach: the angles above are what
            // a guard and a straight ARE, and a harder one is a faster one.
            cycleMs: Math.round(b.cycleMs / (0.75 + intensity * 0.5)),
            hand: "fist"
        }
    }

    // workHeight 0 is a table at the waist, 0.5 a counter at the chest, 1 a
    // shelf at head height. The posture is keyed at those three and read
    // between them.
    var h = opts.workHeight === undefined ? 0.35 : clamp(opts.workHeight, 0, 1)
    function at(k) { return h < 0.5 ? k[0] + (k[1] - k[0]) * h * 2 : k[1] + (k[2] - k[1]) * (h - 0.5) * 2 }
    var upper = at(b.upper), out = at(b.out), elbow = at(b.elbow)
    // The inward yaw, solved for THIS body when it is given one. Turning
    // the arm in by yaw carries the hand inward by a lever times sin(yaw),
    // and the abduction carries it back out by about the upper arm times
    // sin(out). The lever is NOT the hand's forward reach: the yaw is the
    // outermost of the three shoulder rotations and the fold is about an
    // axis the abduction has already tilted, so the hand swings on a longer
    // arm than its reach - measured on the action scene as 1.5 times
    // the reach, at the default height, and scaled with the reach from
    // there. The two hands should end up handGap hand-widths apart, so each
    // has to come in from half the shoulder width to half a hand plus half
    // the gap.
    var yawIn = b.yawIn
    if (opts.shoulderWidth > 0 && opts.armLength > 0 && opts.handWidth > 0) {
        var rad = Math.PI / 180
        var U = opts.armLength * 0.5
        var forward = U * (Math.sin(upper * rad) + Math.sin((upper + elbow) * rad))
        var lever = 1.5 * forward
        var want = opts.shoulderWidth * 0.5 - opts.handWidth * (0.5 + b.handGap * 0.5)
        var travel = want + U * Math.sin(out * rad) * 1.1
        yawIn = Math.asin(clamp(travel / Math.max(0.01, lever), 0, 0.9)) / rad
    }
    // Effort: the amplitude of everything, the tempo, and how much of the
    // body joins in. Past about six tenths the off hand stops working and
    // HOLDS - it clamps the thing the lead hand is hitting - which is what
    // hammering looks like and fiddling does not.
    var amp = 0.45 + intensity * 1.1
    var hold = clamp((intensity - 0.6) / 0.25, 0, 1)
    var heavy = clamp((intensity - 0.5) * 2, 0, 1)
    return {
        name: "use",
        upper: upper,
        out: out,
        elbow: elbow,
        roll: at(b.roll),
        wrist: at(b.wrist),
        lean: at(b.lean) + 10 * heavy,
        curve: at(b.curve),
        headPitch: at(b.headPitch) + 6 * heavy,
        knee: at(b.knee) + 8 * heavy,
        yawIn: yawIn,
        leadAhead: b.leadAhead,
        leadUp: b.leadUp,
        reach: b.reach,
        work: b.work,
        press: b.press,
        settle: b.settle,
        reachUpper: b.reachUpper * amp,
        reachElbow: b.reachElbow * amp,
        reachYaw: b.reachYaw * amp,
        reachChest: b.reachChest * amp,
        reachHead: b.reachHead,
        strokes: b.strokes,
        strokeUpper: b.strokeUpper * amp * (1 + 0.4 * hold),
        strokeElbow: b.strokeElbow * amp * (1 + 0.4 * hold),
        strokeWrist: b.strokeWrist * amp,
        offShare: b.offShare * (1 - 0.85 * hold),
        offPhase: b.offPhase,
        // A heavy stroke lifts slowly and comes down fast.
        snap: hold,
        pressUpper: b.pressUpper * amp,
        pressElbow: b.pressElbow * amp,
        pressWrist: b.pressWrist * amp,
        pressLean: b.pressLean * amp,
        settleUpper: b.settleUpper * amp,
        settleElbow: b.settleElbow * amp,
        glance: b.glance,
        rock: 0.5 + 4.5 * intensity,
        rockYaw: b.rockYaw,
        shift: b.shift,
        cycleMs: Math.round(b.cycleMs * (1.33 - 0.66 * intensity)),
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

// The shape of a JAB over its own slot of the cycle: 0 is the guard, 1 is
// full extension, and a little below zero is the fist drawn back past the
// guard. Not a sine and not a triangle: a jab barely winds up - a jab that
// telegraphs is not a jab - snaps out, sits at the end of its reach for a
// frame, and comes back half again as slowly as it went, overshooting the
// guard by a hair before it settles. \a from is where the fist starts
// (the second of a double jab starts from a guard the first never quite got
// back to) and \a to is where it ends.
function jabAt(u, from, to) {
    from = from === undefined ? 0 : from
    to = to === undefined ? 0 : to
    if (u < 0.10) return from + (-0.06 - from) * easeInOutQuad(ramp(u, 0, 0.10))
    if (u < 0.38) return -0.06 + (1 + 0.06) * easeOutCubic(ramp(u, 0.10, 0.38))
    if (u < 0.46) return 1
    if (u < 0.86) return 1 + (to - 0.04 - 1) * easeInOutQuad(ramp(u, 0.46, 0.86))
    return to - 0.04 + 0.04 * easeInOutQuad(ramp(u, 0.86, 1))
}

// The shape of a CROSS, the same way. The difference from the jab is all in
// the wind-up: the rear fist is drawn back twice as far and for twice as
// long, which is what makes it read as the heavy punch, and the return is
// the slowest thing in the cycle.
function crossAt(u) {
    if (u < 0.16) return -0.12 * easeInOutQuad(ramp(u, 0, 0.16))
    if (u < 0.38) return -0.12 + 1.12 * easeOutCubic(ramp(u, 0.16, 0.38))
    if (u < 0.50) return 1
    if (u < 0.90) return 1 - 1.05 * easeInOutQuad(ramp(u, 0.50, 0.90))
    return -0.05 + 0.05 * easeInOutQuad(ramp(u, 0.90, 1))
}

// The trunk comes back BEFORE the arm does on a cross - the hips unwind,
// then the heel plants, then the arm folds - so the body's own curve is the
// arm's with the return pulled earlier.
function crossTrunkAt(u) {
    if (u < 0.44) return crossAt(u)
    if (u < 0.80) return 1 - easeInOutQuad(ramp(u, 0.44, 0.80))
    return 0
}

// Where \a t falls inside the slot \a span, 0..1, or -1 when outside it.
function within(t, span) {
    if (t < span[0] || t >= span[1]) return -1
    return (t - span[0]) / (span[1] - span[0])
}

// Kept for the working stroke and the gait-style symmetric shapes.
function punchAt(u) {
    if (u < 0.10) return 0
    if (u < 0.32) return easeOutCubic(ramp(u, 0.10, 0.32))
    if (u < 0.42) return 1
    if (u < 0.74) return 1 - easeInOutQuad(ramp(u, 0.42, 0.74))
    return 0
}

// The shape of one working stroke: out and back, both halves eased, over the
// whole of its own cycle. Unlike the punch this one never rests - work is
// continuous, and a pause in it reads as the character stopping. \a snap
// pulls the shape toward a heavy one: a slow lift and a fast drop.
function strokeAt(u, snap) {
    u = u - Math.floor(u)
    var even = u < 0.5 ? easeInOutQuad(u * 2) : 1 - easeInOutQuad((u - 0.5) * 2)
    if (!snap) return even
    var hard = u < 0.7 ? easeInOutQuad(u / 0.7) : 1 - easeOutCubic((u - 0.7) / 0.3)
    return even + (hard - even) * snap
}

// A beat's envelope: 0 at both ends of the beat, 1 through the middle, eased
// in over the first third and out over the last. Every beat's pose is the
// base pose plus its own delta under this, so the joints are at the base at
// every beat boundary and nothing has to be matched between beats.
function beatAt(u) {
    if (u < 0) return 0
    if (u < 0.34) return easeInOutQuad(u / 0.34)
    if (u < 0.66) return 1
    if (u < 1) return 1 - easeInOutQuad((u - 0.66) / 0.34)
    return 0
}

// --- the pose -----------------------------------------------------------------

// One arm, in the shape poseAt answers with. \a side is 1 for the right arm
// and -1 for the left: `out` and `roll` are the two angles whose sign means
// "away from the body" rather than a direction in space, and `yaw` swings the
// arm IN across the chest, so all three are mirrored here and nowhere else.
//
// The yaw is negated against the side: a positive Y rotation turns a forward
// pointing forearm toward +X, which on the right arm is outward. Measured on
// the action scene - written the other way round, the rear fist of the guard
// sat a head and a half outside the face.
function arm(pitch, yaw, out, elbow, wrist, roll, side) {
    return {
        upper: [pitch, -side * yaw, side * out],
        lower: [elbow, 0, 0],
        hand: [wrist, side * roll * 90, 0]
    }
}

// \a out carries the whole leg away from the body's centre line, signed by
// \a side the way an arm's is: it is what puts a stance's feet apart.
// \a pivot turns the foot on its ball - the rear foot of a cross.
function leg(upper, lower, foot, out, side, pivot) {
    return {
        upper: [upper, 0, (out === undefined ? 0 : out) * (side === undefined ? 1 : side)],
        lower: [lower, 0, 0],
        foot: [foot, pivot === undefined ? 0 : pivot, 0]
    }
}

// The pose \a table holds at phase \a t of its cycle, 0..1. Pure: the same
// answer the running cycle gives at that moment, which is what lets the sheet
// be drawn from it.
//
// The wrist roll comes back as a FRACTION of a quarter turn rather than in
// degrees, because the degrees belong to the character (handRestRoll) and not
// to the action. Whoever applies the pose multiplies.
function poseAt(table, t, cycle) {
    return table.name === "fight" ? fightAt(table, t) : useAt(table, t, cycle)
}

function fightAt(table, t) {
    t = t - Math.floor(t)
    var TAU = Math.PI * 2

    // Where each punch is. The lead hand throws twice, the rear once; the
    // second jab picks up from where the first left off.
    var u1 = within(t, table.jab1)
    var u2 = within(t, table.jab2)
    var uc = within(t, table.cross)
    var jab = u1 >= 0 ? jabAt(u1, 0, 0.3)
            : u2 >= 0 ? jabAt(u2, 0.3, 0)
            : 0
    var cross = uc >= 0 ? crossAt(uc) : 0
    var crossTrunk = uc >= 0 ? crossTrunkAt(uc) : 0
    // The load of the cross: the wind-up, before the fist goes. Both fists
    // rise a touch, the knees straighten, the weight rocks back.
    var load = uc >= 0 ? clamp(-crossAt(uc) / 0.12, 0, 1) : 0
    // How committed the body is: the bounce and the weave fade under a
    // punch, because a body that is throwing is not also dancing.
    var commit = clamp(Math.max(Math.abs(jab), cross), 0, 1)
    var loose = 1 - commit

    // The bounce, biased DOWN from the top of its range, and the weave. The
    // dips fall at the START of each punch, so a punch goes up out of one
    // rather than landing in one, and the load of the cross stands tall.
    var bob = 0.5 * (1 + Math.cos(TAU * table.bobs * t)) * loose
    var wv = Math.sin(TAU * t) * loose
    var wvLate = Math.sin(TAU * t - 0.5) * loose

    // The guard, per arm. The lead is the left (-1), the rear the right.
    function guard(upper, out, yaw, elbow, roll, side, lift) {
        return arm(-upper, yaw, out, -(elbow + lift), table.guardWrist, roll, side)
    }
    // A punch from its guard, by \a p: 0 the guard, 1 full extension, and a
    // little under zero drawn back past it. \a swing is the yaw at full
    // extension - negative is outward.
    function punch(upper, out, yaw, elbow, roll, reach, p, side, swing) {
        var q = p * reach
        return arm(-(upper + (table.punchUpper - upper) * q),
                   yaw * (1 - p) + swing * clamp(p, 0, 1),
                   out + (table.punchOut - out) * q,
                   -(elbow + (table.punchElbow - elbow) * q),
                   table.guardWrist + (table.punchWrist - table.guardWrist) * clamp(p, 0, 1),
                   roll + (table.punchRoll - roll) * clamp(p, 0, 1),
                   side)
    }

    var leadArm = jab !== 0
        ? punch(table.leadUpper, table.leadOut, table.leadIn, table.leadElbow,
                table.leadRoll, table.jabReach, jab, -1, -table.jabYaw)
        : guard(table.leadUpper, table.leadOut, table.leadIn, table.leadElbow,
                table.leadRoll, -1, 6 * load)
    var rearArm = cross !== 0
        ? punch(table.rearUpper, table.rearOut, table.rearIn, table.rearElbow,
                table.rearRoll, 1, cross, 1, 0)
        : guard(table.rearUpper, table.rearOut, table.rearIn, table.rearElbow,
                table.rearRoll, 1, 0)

    // The trunk turns INTO the punch. A positive yaw brings the -X (left)
    // shoulder toward +Z, which is the way the character faces - so the jab
    // adds to the blade and the cross takes it away and past.
    var jabP = clamp(jab, 0, 1)
    var hipYaw = table.blade + table.jabHip * jabP - table.crossHip * crossTrunk
    var chestYaw = table.jabChest * jabP - table.crossChest * crossTrunk
                 + table.weave * wv
    var chestLean = table.guardLean + table.crossLean * crossTrunk

    // The stance. The lead (left, -X) leg is forward, so its hip is
    // negative; the rear heel is up, and the rear foot turns on its ball as
    // the cross goes through. The knees take the bounce and the load.
    var knee = table.bobKnee * bob - 4 * load
    var rearLeg = leg(table.rearHip, table.rearKnee + knee, table.rearHeel,
                      table.stanceWide, 1, -table.crossPivot * crossTrunk)
    var leadLeg = leg(-table.leadHip, table.leadKnee + knee + 3 * crossTrunk, 0,
                      table.stanceWide, -1, 0)

    // The figure sits at the height that plants the lead foot - a bent leg
    // is a shorter leg - and dips from there for the bounce.
    var plant = 0.5 * (1 - Math.cos(table.leadHip * Math.PI / 180))
              + 0.5 * (1 - Math.cos((table.leadKnee - table.leadHip) * Math.PI / 180))
    var lift = -plant - table.bob * bob + 0.01 * load

    return {
        rightArm: rearArm,
        leftArm: leadArm,
        rightLeg: rearLeg,
        leftLeg: leadLeg,
        hip: [0, 0, 0],
        // The blade lives on the trunk group, which carries the hips and the
        // legs with it - which is exactly what a stance is. The sway is a
        // roll of the same group, and the chest rolls back against it.
        torso: [0, hipYaw, table.sway * wv],
        belly: [0, 0, 0],
        chest: [chestLean, chestYaw, -table.sway * 0.6 * wv],
        // The chin stays down and the face turns back toward the opponent,
        // following the shoulders round a little late.
        head: [table.headPitch + 4 * crossTrunk,
               -table.blade * table.headTurn - chestYaw * 0.4 - table.weave * 0.5 * wvLate,
               0],
        lift: lift,
        hand: table.hand
    }
}

function useAt(table, t, cycle) {
    t = t - Math.floor(t)
    cycle = cycle === undefined ? 0 : cycle
    var TAU = Math.PI * 2

    // Where in which beat. The envelopes are 0 at every boundary, so the
    // beats need no matching and the base posture is what is left between.
    var ua = within(t, table.reach)
    var uw = within(t, table.work)
    var up = within(t, table.press)
    var us = within(t, table.settle)
    var reach = beatAt(ua)
    var work = beatAt(uw)
    var press = beatAt(up)
    var settle = beatAt(us)
    // The eye arrives before the hand: the head's reach envelope runs a
    // sixth of the beat early. And it leaves the press late.
    var reachEarly = ua >= 0 ? beatAt(clamp(ua + 0.16, 0, 1)) : (us >= 0 && us > 0.84 ? beatAt(us - 0.84) : 0)
    var pressLate = up >= 0 ? beatAt(clamp(up - 0.12, 0, 1)) : (us >= 0 && us < 0.12 ? beatAt(0.88 + us) : 0)
    // Every fourth cycle the settle is a proper look up - the variation
    // that keeps a loop from being noticed as one.
    var glanceUp = cycle % 4 === 3 ? 2.2 : 1

    // The micro-strokes through the work beat, the off hand behind the lead.
    var lead = uw >= 0 ? strokeAt(uw * table.strokes, table.snap) * work : 0
    var off = uw >= 0 ? strokeAt(uw * table.strokes - table.offPhase, 0) * work * table.offShare : 0

    // One arm: the base posture for this height plus the beats' deltas.
    // \a isLead is the hand that reaches and presses; the other holds.
    function side(sign, isLead, stroke) {
        var ahead = isLead ? 1 : 0
        var upper = table.upper + table.leadAhead * ahead
                  + table.reachUpper * reach * ahead
                  + table.strokeUpper * stroke
                  + table.pressUpper * press * (isLead ? 1 : 0.4)
                  + table.settleUpper * settle
        var elbow = table.elbow - table.leadUp * ahead
                  - table.reachElbow * reach * ahead
                  - table.strokeElbow * stroke
                  - table.pressElbow * press * (isLead ? 1 : 0.4)
                  + table.settleElbow * settle
        var yaw = table.yawIn + table.reachYaw * reach * ahead
        // The wrist flicks at the end of each stroke, a little after the
        // hand stops - it is the stroke's own curve a beat late.
        var flick = uw >= 0 ? (strokeAt(uw * table.strokes - 0.12, 0) - 0.5) * 2 * work : 0
        var wrist = table.wrist - table.strokeWrist * flick * (isLead ? 1 : table.offShare)
                  - table.pressWrist * press * (isLead ? 1 : 0.4)
        return arm(-upper, yaw, table.out, -elbow, wrist, table.roll, sign)
    }

    // The trunk: the lean for this height, rounded or arched, the rock, and
    // the extra it gives to a reach and a press.
    var lean = table.lean + table.pressLean * press + table.rock * Math.sin(TAU * t)
    var curve = table.curve
    var belly = lean * 0.4 - curve * 0.5
    var chest = lean * 0.6 + curve * 0.5
    var chestYaw = table.rockYaw * Math.sin(TAU * t + 1.0)
                 // Shoulders toward the reach, a little before the hand.
                 + table.reachChest * reachEarly

    // The legs: both knees a little bent, the lead foot a little ahead, and
    // the weight going across once a cycle, off the beat.
    var shift = table.shift * Math.sin(TAU * t + 0.9)
    var rightLeg = leg(-3, table.knee + shift, 0, 3, 1)
    var leftLeg = leg(2, table.knee - shift, 0, 3, -1)
    var plant = 0.5 * (1 - Math.cos(3 * Math.PI / 180))
              + 0.5 * (1 - Math.cos((table.knee - 3) * Math.PI / 180))

    return {
        rightArm: side(1, true, lead),
        leftArm: side(-1, false, off),
        rightLeg: rightLeg,
        leftLeg: leftLeg,
        // The pelvis gives the belly's bend straight back, so the legs stay
        // upright under a rounded back.
        hip: [-belly, 0, 0],
        torso: [0, 0, 0],
        belly: [belly, 0, 0],
        chest: [chest, chestYaw, 0],
        // Down at the work; ahead of the hand on a reach, behind it on a
        // press, and up for a moment at the end of the cycle.
        head: [table.headPitch + table.glance * settle * glanceUp - 4 * pressLate,
               table.reachHead * reachEarly + (lead - off) * 3,
               0],
        lift: -plant,
        hand: table.hand
    }
}
