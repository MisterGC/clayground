// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The martial-arts move set: the fourteen moves of the reference sheet
// (#238), as poses rather than as animations.
//
// Qt-free on purpose (.pragma library, no engine, no clock, no randomness),
// for the same reason gait.js and action.js are: `node martialarts.test.js`
// checks the poses in a second, and "a front kick puts the foot above the
// hip" is then an exact assertion on numbers rather than an impression from
// a screenshot.
//
// HOW A MOVE IS WRITTEN HERE. Not as a curve per joint - that is what the
// boxing cycle in action.js does, and it is the right shape for one cycle
// authored once. A SET is a different problem: fourteen moves, and more
// later, each of which has to start and end somewhere the next one can pick
// up from. So a move here is a short list of KEY FRAMES, each frame a flat
// object of named angles, and poseAt() mixes the two frames around the phase
// it is asked for. Three things fall out of that:
//
//   * a move whose first and last key are the ready stance returns to the
//     stance by construction, so any two moves chain and any loop loops;
//   * effort scales a move by mixing its keys toward the stance, which
//     changes the size of a move and never its shape;
//   * the knockdown can END lying down and the get-up START there, simply by
//     sharing that frame - which is what "13. KNOCKDOWN" and "14. GET-UP"
//     are on the sheet.
//
// SIGNS. The frame is written in HUMAN terms - "the upper arm is 32 degrees
// forward of hanging", "the knee is flexed 26 degrees" - and finish() is the
// one place that turns those into the joints' own conventions, which are
// action.js's and are the opposite way round:
//
//   * upper/lower arm and leg x: NEGATIVE pitches the limb forward.
//   * upper arm/leg z: positive carries the limb OUT from the centre line on
//     the +X (right) side; frames are written unsigned and mirrored at use.
//   * hand y: the wrist roll about the forearm, as a FRACTION of a quarter
//     turn - the degrees are the character's (handRestRoll), not the move's.
//   * foot y: turns the foot on its ball. NOT mirrored - a positive turn
//     takes either foot's toes toward +X, which is out on the right foot and
//     in on the left.
//   * head x: positive looks DOWN.
//   * the arm/leg direction that matters for a strike is upper + elbow:
//     0 is straight down, 90 forward and level, 180 straight up.
//
// LEAD AND REAR are the orthodox pair: the LEFT side leads (it is the side
// turned toward the opponent and the side that jabs), the RIGHT is the rear
// and throws the cross, the uppercut and every kick here.
//
// MOVES ARE IN PLACE. lift and drift move the BODY over its own feet, in leg
// heights, and both come back to zero by the end of a move; carrying the
// character across the floor is the caller's business, not the set's.

.pragma library

// --- the ready stance ---------------------------------------------------------
//
// Frame 1 of the sheet, and the frame every other move on it is written
// against. Wider, lower and less bladed than the boxing guard in action.js:
// a boxer stands on the balls of both feet to move, and this stance is a
// platform to kick from, so the feet are further apart, the knees are
// further bent and the rear foot is turned out rather than trailing.
var STANCE = {
    // The trunk. The blade turns the lead shoulder toward the opponent and
    // carries the hips and the legs with it - that is what a stance is.
    blade: 28,
    lean: 8,          // the chest forward over the guard
    headPitch: 7,     // chin down, looking through the brows
    headTurn: 0.7,    // how much of the blade the face turns back

    // The guard. The lead hand is further out and lower than the rear, which
    // is tucked at the jaw: a guard whose two fists are a mirror pair reads
    // as a pose, one whose two are different reads as a person.
    leadUp: 32, leadOut: 15, leadIn: 16, leadElbow: 112, leadRoll: 0.7,
    rearUp: 42, rearOut: 6,  rearIn: 36, rearElbow: 128, rearRoll: 0.9,
    wrist: 0,

    // The feet: a long stance, both knees bent, the rear heel a little up
    // and the rear foot turned out to push from.
    leadLegUp: 26, leadKnee: 26, leadToe: 0,  leadPivot: 0,
    rearLegUp: -20, rearKnee: 22, rearToe: 12, rearPivot: 30,
    legOut: 12,

    hand: "fist"
}

// How far below its standing height the figure sits on a leg folded like
// this, in leg heights: a bent leg is a shorter leg, and without this every
// crouch in the set would leave the feet hanging under the floor.
//
// The foot is followed through the joints rather than approximated by the
// two pitches: the leg is also carried \a out to the side, and the sheet's
// stances are wide enough that ignoring that puts a deep crouch a tenth of a
// leg into the ground. The rotations are the joints' own, in the order the
// engine applies them - Z, then X, then Y.
function plant(legUp, knee, out) {
    var rad = Math.PI / 180
    out = out === undefined ? STANCE.legOut : out
    var co = Math.cos(out * rad)
    var cu = Math.cos(legUp * rad), su = Math.sin(legUp * rad)
    var ck = Math.cos(knee * rad), sk = Math.sin(knee * rad)
    // The thigh, straight down then swung \a out then pitched \a legUp
    // forward; and the shin, which carries all of that plus its own flexion.
    // Only the vertical component is wanted.
    var thighY = -co * cu
    var shinY = -ck * co * cu - sk * su
    // The two segments are half the leg each (Leg::upperRatio).
    return 1 + 0.5 * thighY + 0.5 * shinY
}

// Sets \a f's lift so the figure stands on whichever of its two feet reaches
// the floor first, plus \a extra for a deliberate rise or give. Every
// standing frame in the set goes through it, which is why a crouch here sits
// ON the floor rather than a tenth of a leg into it and a kick does not lift
// the standing foot off it.
function settle(f, extra) {
    var lead = plant(f.leadLegUp, f.leadKnee, f.leadLegOut)
    var rear = plant(f.rearLegUp, f.rearKnee, f.rearLegOut)
    f.lift = -Math.min(lead, rear) + (extra === undefined ? 0 : extra)
    return f
}

// The ready stance as a frame. Every builder below starts from a copy of
// this and changes what its move changes, which is why a move reads as the
// handful of angles that make it and not as sixteen joints written out.
function ready(T) {
    var S = T.stance
    var f = {
        leadUp: S.leadUp, leadOut: S.leadOut, leadIn: S.leadIn,
        leadElbow: S.leadElbow, leadWrist: S.wrist, leadRoll: S.leadRoll,
        rearUp: S.rearUp, rearOut: S.rearOut, rearIn: S.rearIn,
        rearElbow: S.rearElbow, rearWrist: S.wrist, rearRoll: S.rearRoll,

        leadLegUp: S.leadLegUp, leadKnee: S.leadKnee, leadToe: S.leadToe,
        leadLegOut: S.legOut, leadPivot: S.leadPivot,
        rearLegUp: S.rearLegUp, rearKnee: S.rearKnee, rearToe: S.rearToe,
        rearLegOut: S.legOut, rearPivot: S.rearPivot,

        blade: S.blade, torsoLean: 0, torsoRoll: 0,
        hipPitch: 0, hipYaw: 0,
        belly: S.lean * 0.35, chest: S.lean * 0.65, chestYaw: 0, chestRoll: 0,
        headPitch: S.headPitch, headYaw: 0, headRoll: 0,

        lift: 0,
        drift: 0,
        hand: S.hand
    }
    settle(f)
    look(f, T)
    return f
}

// The face turns back out of the blade toward the opponent, following the
// shoulders a little late. Called after a frame's trunk is set, so a move
// that turns the body does not leave the head looking past the target.
function look(f, T, k) {
    k = k === undefined ? T.stance.headTurn : k
    f.headYaw = -(f.blade + f.chestYaw) * k
    return f
}

// A frame with \a over's fields written over a copy of \a f. The frames are
// flat by design so this is the whole of frame composition.
function over(f, o) {
    var r = {}
    for (var k in f) r[k] = f[k]
    for (var j in o) r[j] = o[j]
    return r
}

// --- shaping ------------------------------------------------------------------

function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v }

function easeInOutQuad(u) {
    return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2
}

function easeOutCubic(u) { return 1 - Math.pow(1 - u, 3) }

function easeInCubic(u) { return u * u * u }

// The named curves a key may arrive on. "out" is the one that makes a strike
// a strike: it covers most of its distance in the first third of its slot.
function shape(name, u) {
    if (name === "lin") return u
    if (name === "out") return easeOutCubic(u)
    if (name === "in") return easeInCubic(u)
    if (name === "hold") return u >= 1 ? 1 : 0
    return easeInOutQuad(u)
}

// Two frames mixed, \a k from 0 (all \a a) to 1 (all \a b). Numbers are read
// between; the hand pose is a name and cannot be, so it changes at the
// halfway point.
function mixFrame(a, b, k) {
    var r = {}
    for (var f in a) {
        var x = a[f], y = b[f]
        r[f] = (typeof x === "number" && typeof y === "number")
             ? x + (y - x) * k
             : (k < 0.5 ? x : y)
    }
    return r
}

// The same, for the poses finish() answers with - the shape the animator
// writes onto the joints. Used to ease INTO a move from wherever the body
// happens to be standing, which is a different thing from mixing key frames:
// the pose at the far end is already computed, and what is being blended is
// the joints' current state.
function mixPose(a, b, k) {
    if (!a) return b
    if (!b) return a
    function v3(p, q) { return [p[0] + (q[0] - p[0]) * k,
                                p[1] + (q[1] - p[1]) * k,
                                p[2] + (q[2] - p[2]) * k] }
    function limb(p, q) { return { upper: v3(p.upper, q.upper),
                                   lower: v3(p.lower, q.lower),
                                   hand: v3(p.hand, q.hand) } }
    function foot(p, q) { return { upper: v3(p.upper, q.upper),
                                   lower: v3(p.lower, q.lower),
                                   foot: v3(p.foot, q.foot) } }
    return {
        rightArm: limb(a.rightArm, b.rightArm),
        leftArm: limb(a.leftArm, b.leftArm),
        rightLeg: foot(a.rightLeg, b.rightLeg),
        leftLeg: foot(a.leftLeg, b.leftLeg),
        hip: v3(a.hip, b.hip),
        torso: v3(a.torso, b.torso),
        belly: v3(a.belly, b.belly),
        chest: v3(a.chest, b.chest),
        head: v3(a.head, b.head),
        lift: a.lift + (b.lift - a.lift) * k,
        drift: a.drift + (b.drift - a.drift) * k,
        hand: k < 0.5 ? a.hand : b.hand
    }
}

// --- turning a frame into a pose ----------------------------------------------

// One arm, in the shape poseAt answers with. \a side is 1 for the right arm
// and -1 for the left. Identical to action.js's - the two models write the
// same joints and a second convention for them would be a bug waiting.
function arm(pitch, yaw, out, elbow, wrist, roll, side) {
    return {
        upper: [pitch, -side * yaw, side * out],
        lower: [elbow, 0, 0],
        hand: [wrist, side * roll * 90, 0]
    }
}

function leg(upper, lower, foot, out, side, pivot) {
    return {
        upper: [upper, 0, (out === undefined ? 0 : out) * (side === undefined ? 1 : side)],
        lower: [lower, 0, 0],
        foot: [foot, pivot === undefined ? 0 : pivot, 0]
    }
}

// The one place the frame's human signs become the joints'. Everything above
// says "forward" and "flexed"; everything below the joints' own minus signs.
function finish(f) {
    return {
        rightArm: arm(-f.rearUp, f.rearIn, f.rearOut, -f.rearElbow,
                      f.rearWrist, f.rearRoll, 1),
        leftArm: arm(-f.leadUp, f.leadIn, f.leadOut, -f.leadElbow,
                     f.leadWrist, f.leadRoll, -1),
        rightLeg: leg(-f.rearLegUp, f.rearKnee, f.rearToe, f.rearLegOut, 1, f.rearPivot),
        leftLeg: leg(-f.leadLegUp, f.leadKnee, f.leadToe, f.leadLegOut, -1, f.leadPivot),
        hip: [f.hipPitch, f.hipYaw, 0],
        // The blade lives on the trunk GROUP, which carries the hips and the
        // legs with it; the two spine segments bend on top of it.
        torso: [f.torsoLean, f.blade, f.torsoRoll],
        belly: [f.belly, 0, 0],
        chest: [f.chest, f.chestYaw, f.chestRoll],
        head: [f.headPitch, f.headYaw, f.headRoll],
        lift: f.lift,
        drift: f.drift,
        hand: f.hand
    }
}

// --- the moves ----------------------------------------------------------------
//
// Each entry is a section of the sheet, a duration, whether it loops, and a
// list of keys. A key's `ease` is how the move ARRIVES at it from the key
// before, so the shape of a strike is written where the strike lands.
//
// `amp` says whether effort may scale the move. Off for the two ground moves
// only: a knockdown scaled up misses the floor, and one scaled down does not
// reach it.

var MOVES = [

// ------------------------------------------------------------- standing basics

{
    name: "stance", label: "neutral stance", group: "standing",
    ms: 2400, loop: true, amp: true,
    keys: function (T) {
        var b = ready(T)
        // A stance that does not breathe is a statue within two seconds.
        // The weight goes across and the knees give a little with it.
        var mid = over(b, {
            leadKnee: b.leadKnee + 3, rearKnee: b.rearKnee + 3,
            torsoRoll: 2, chestRoll: -1.2,
            chest: b.chest + 2
        })
        settle(mid, -0.02)
        return [{ t: 0, f: b },
                { t: 0.5, f: look(mid, T) },
                { t: 1, f: b }]
    }
},

{
    name: "step", label: "forward / back step", group: "standing",
    ms: 1300, loop: true, amp: true,
    keys: function (T) {
        var b = ready(T)
        // Forward: the rear foot pushes, the lead knee opens, and the body
        // travels a third of a leg over its own feet. Back: the mirror of
        // it, shorter - stepping back is a shorter step than stepping in.
        var fwd = over(b, {
            drift: 0.32,
            leadLegUp: b.leadLegUp + 6, leadKnee: b.leadKnee - 6,
            rearLegUp: b.rearLegUp - 6, rearKnee: b.rearKnee - 6,
            rearToe: b.rearToe + 14,
            chest: b.chest + 4, blade: b.blade + 3
        })
        var back = over(b, {
            drift: -0.18,
            leadLegUp: b.leadLegUp - 4, leadKnee: b.leadKnee + 6,
            rearLegUp: b.rearLegUp + 4, rearKnee: b.rearKnee + 6,
            rearToe: b.rearToe - 8,
            chest: b.chest - 3, blade: b.blade - 2
        })
        settle(fwd)
        settle(back)
        return [{ t: 0, f: b },
                { t: 0.32, ease: "out", f: look(fwd, T) },
                { t: 0.52, f: b },
                { t: 0.82, ease: "out", f: look(back, T) },
                { t: 1, f: b }]
    }
},

{
    name: "guard", label: "high guard / block", group: "standing",
    ms: 1500, loop: true, amp: true,
    keys: function (T) {
        var b = ready(T)
        // The cover: both forearms come up in front of the face, the elbows
        // stay in against the ribs, the chin tucks behind them. The whole
        // block is that the head goes BEHIND the arms - a guard whose hands
        // are merely higher reads as a shrug.
        var up = over(b, {
            leadUp: 58, leadElbow: 128, leadIn: 30, leadOut: 10,
            rearUp: 62, rearElbow: 132, rearIn: 34, rearOut: 8,
            headPitch: 17, chest: b.chest + 7,
            leadKnee: b.leadKnee + 6, rearKnee: b.rearKnee + 6
        })
        settle(up)
        return [{ t: 0, f: b },
                { t: 0.34, ease: "out", f: look(up, T, 0.5) },
                { t: 0.62, f: look(up, T, 0.5) },
                { t: 1, f: b }]
    }
},

{
    name: "jab", label: "jab (straight punch)", group: "standing",
    ms: 460, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // A jab barely winds up - one that telegraphs is not a jab - so the
        // load is two degrees and a breath, and the whole move is the
        // extension and the slower way back.
        var load = over(b, {
            leadUp: b.leadUp - 3, leadElbow: b.leadElbow + 6,
            blade: b.blade + 3
        })
        // At full extension the arm is level and nearly straight, the fist
        // has turned over, and the lead shoulder has swung back OUT: the
        // lead shoulder is already round toward the opponent, so a jab
        // straight out of it crosses the centre line.
        var out = over(b, {
            leadUp: 88, leadElbow: 12, leadIn: -12, leadOut: 5,
            leadRoll: 0.1, leadWrist: 0,
            blade: b.blade + 7, chestYaw: 9,
            leadKnee: b.leadKnee - 7, rearToe: b.rearToe + 8,
            drift: 0.06
        })
        settle(load)
        settle(out)
        return [{ t: 0, f: b },
                { t: 0.14, f: look(load, T) },
                { t: 0.42, ease: "out", f: look(out, T, 0.85) },
                { t: 0.54, f: look(out, T, 0.85) },
                { t: 1, f: b }]
    }
},

{
    name: "cross", label: "cross (strong punch)", group: "standing",
    ms: 620, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // The cross is the trunk, not the arm: the rear fist is drawn back
        // twice as far and for twice as long as a jab's, and then the hips
        // turn THROUGH the blade and the rear heel comes off the floor.
        var load = over(b, {
            rearUp: b.rearUp - 5, rearElbow: b.rearElbow + 8,
            blade: b.blade + 7, rearKnee: b.rearKnee + 7
        })
        settle(load, -0.02)
        var out = over(b, {
            rearUp: 92, rearElbow: 10, rearIn: 6, rearOut: 4,
            rearRoll: 0.1, rearWrist: 0,
            blade: b.blade - 22, chestYaw: -14,
            chest: b.chest + 11,
            rearLegUp: b.rearLegUp + 8, rearKnee: 12,
            rearToe: b.rearToe + 22, rearPivot: 62,
            leadKnee: b.leadKnee + 4,
            drift: 0.1
        })
        settle(out)
        return [{ t: 0, f: b },
                { t: 0.2, f: look(load, T) },
                { t: 0.46, ease: "out", f: look(out, T, 0.85) },
                { t: 0.58, f: look(out, T, 0.85) },
                { t: 1, f: b }]
    }
},

{
    name: "uppercut", label: "rising uppercut", group: "standing",
    ms: 640, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // A rising punch is a rising BODY: the knees fold, the fist drops
        // below the ribs, and then the legs drive the whole figure up and
        // the arm goes with it. Thrown from the arm alone it is a hook that
        // happens to point upward.
        var load = over(b, {
            rearUp: 20, rearElbow: 55, rearIn: 26,
            leadKnee: b.leadKnee + 12, rearKnee: b.rearKnee + 12,
            chest: b.chest + 8, headPitch: b.headPitch + 5,
            blade: b.blade + 6
        })
        settle(load, -0.03)
        // Forearm at up + elbow = 165 degrees: the fist finishes above the
        // head, which is where the sheet has it.
        var up = over(b, {
            rearUp: 85, rearElbow: 80, rearIn: 12, rearOut: 12, rearRoll: 1,
            leadUp: 46, leadElbow: 124, leadIn: 30,
            leadKnee: 14, rearKnee: 12,
            chest: b.chest - 10, chestYaw: -18, blade: b.blade - 10,
            headPitch: -8, rearToe: b.rearToe + 20, rearPivot: 52
        })
        settle(up, 0.04)
        return [{ t: 0, f: b },
                { t: 0.22, f: look(load, T) },
                { t: 0.48, ease: "out", f: look(up, T, 0.8) },
                { t: 0.6, f: look(up, T, 0.8) },
                { t: 1, f: b }]
    }
},

// ------------------------------------------------------------ crouched basics

{
    name: "lowGuard", label: "low guard / block", group: "crouched",
    ms: 2000, loop: true, amp: true,
    keys: function (T) {
        var b = ready(T)
        // Dropped under the line of a high attack, guard still up. The
        // crouch is in the knees and not in the back: a figure that folds
        // forward instead has put its head where the block was covering.
        var low = over(b, {
            // A crouch that is only a few degrees lower than the stance is
            // not a crouch: side by side on the sheet it read as the same
            // figure. The knees fold most of a right angle, which drops the
            // whole figure a quarter of a leg, and the rear heel comes up -
            // a long stance folded this far cannot keep both soles down.
            leadLegUp: 38, leadKnee: 82, rearLegUp: -10, rearKnee: 66,
            rearToe: b.rearToe + 20,
            leadUp: 34, leadElbow: 120, leadIn: 22,
            rearUp: 40, rearElbow: 130, rearIn: 38,
            chest: b.chest + 9, belly: b.belly + 3,
            headPitch: b.headPitch + 5, blade: b.blade - 6
        })
        settle(low)
        var lower = over(low, {
            leadKnee: 88, rearKnee: 72, torsoRoll: 1.5
        })
        settle(lower)
        return [{ t: 0, f: look(low, T) },
                { t: 0.5, f: look(lower, T) },
                { t: 1, f: look(low, T) }]
    }
},

{
    name: "sweep", label: "low sweep kick", group: "crouched",
    ms: 950, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // All the way down onto one hand, and the rear leg goes round at
        // ankle height. The planted hand is the move: without it the figure
        // is squatting and waving a leg, with it the weight is somewhere
        // the leg can swing under.
        var down = over(b, {
            leadLegUp: 30, leadKnee: 92, rearLegUp: -18, rearKnee: 78,
            leadUp: -26, leadElbow: 22, leadOut: 26, leadIn: -10,
            leadRoll: 0.1, leadWrist: 20,
            rearUp: 34, rearElbow: 96, rearIn: 30,
            chest: b.chest + 24, belly: b.belly + 10, hipPitch: -12,
            headPitch: 20, blade: b.blade - 8,
            hand: "open"
        })
        settle(down)
        var round = over(down, {
            rearLegUp: -6, rearKnee: 6, rearLegOut: 62, rearToe: 8,
            rearPivot: -20,
            rearUp: 40, rearElbow: 70, rearIn: 40,
            blade: b.blade - 26, chestYaw: -22, torsoRoll: 10,
            leadKnee: 96
        })
        settle(round)
        return [{ t: 0, f: b },
                { t: 0.26, f: look(down, T, 0.5) },
                { t: 0.56, ease: "out", f: look(round, T, 0.4) },
                { t: 0.74, f: look(down, T, 0.5) },
                { t: 1, f: b }]
    }
},

// ------------------------------------------------------------ standing kicks

{
    name: "frontKick", label: "front kick", group: "kicks",
    ms: 720, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // Chamber first, then extend: a leg that goes out straight from the
        // stance is a swing, and the difference between a swing and a kick
        // is entirely the knee that came up before it.
        var chamber = over(b, {
            rearLegUp: 62, rearKnee: 96, rearToe: 18, rearLegOut: 4,
            leadLegUp: 10, leadKnee: 18, leadPivot: -12,
            leadUp: 40, leadElbow: 118, rearUp: 46, rearElbow: 130,
            chest: b.chest - 5, blade: b.blade - 6
        })
        settle(chamber)
        var out = over(chamber, {
            rearLegUp: 112, rearKnee: 8, rearToe: 26,
            leadKnee: 14, leadPivot: -18,
            leadUp: 12, leadElbow: 58, leadOut: 34,
            rearUp: 54, rearElbow: 118, rearOut: 20,
            chest: b.chest - 14, belly: b.belly - 6, hipPitch: -8,
            headPitch: 0, blade: b.blade - 10
        })
        settle(out, 0.02)
        return [{ t: 0, f: b },
                { t: 0.24, f: look(chamber, T, 0.8) },
                { t: 0.48, ease: "out", f: look(out, T, 0.8) },
                { t: 0.6, f: look(out, T, 0.8) },
                { t: 1, f: b }]
    }
},

{
    name: "roundhouse", label: "high roundhouse kick", group: "kicks",
    ms: 860, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // Round rather than straight: the leg is chambered out to the SIDE,
        // the supporting foot turns its heel toward the target, and the
        // trunk falls away from the kick to pay for the height.
        var chamber = over(b, {
            rearLegUp: 78, rearKnee: 100, rearLegOut: 34, rearToe: 16,
            leadKnee: 20, leadPivot: -26,
            torsoRoll: -10, blade: b.blade + 8,
            leadUp: 44, leadElbow: 118, rearUp: 36, rearElbow: 110
        })
        settle(chamber)
        // HOW HIGH A ROUND KICK GETS is not the pitch alone. The leg is
        // carried out to the side first and pitched forward second (the
        // joint's rotations are applied Z, then X, then Y), so the swing out
        // is also the CEILING: a leg carried d degrees out cannot be lifted
        // past 90 - d above the horizontal however hard it is pitched, and at
        // sixty out - which is what a round kick looks like on paper - the
        // foot cannot reach higher than the belt. A third of a turn out and a
        // pitch well past the vertical is what puts it at chest height, and
        // what makes the kick read as ROUND is then the trunk falling away
        // from it and the supporting heel turning, not the leg's own swing.
        var out = over(chamber, {
            rearLegUp: 136, rearKnee: 10, rearLegOut: 34, rearToe: 24,
            leadKnee: 12, leadPivot: -58, leadLegUp: b.leadLegUp - 8,
            torsoRoll: -28, blade: b.blade - 18, chestYaw: -20,
            leadUp: 52, leadElbow: 104, leadIn: 40,
            rearUp: 14, rearElbow: 42, rearOut: 30,
            chest: b.chest - 6
        })
        settle(out, 0.03)
        return [{ t: 0, f: b },
                { t: 0.26, f: look(chamber, T, 0.8) },
                { t: 0.54, ease: "out", f: look(out, T, 0.55) },
                { t: 0.66, f: look(out, T, 0.55) },
                { t: 1, f: b }]
    }
},

// --------------------------------------------------------------- airborne moves

{
    name: "jumpPunch", label: "jumping forward punch", group: "airborne",
    ms: 840, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        // Crouch, leave the floor, land in a crouch. The legs TRAIL behind
        // the punch in the air - a figure that keeps its stance airborne
        // reads as being lifted rather than as jumping.
        var load = over(b, {
            leadKnee: 55, rearKnee: 55, leadLegUp: 22, rearLegUp: -16,
            leadUp: 10, leadElbow: 90, rearUp: 14, rearElbow: 95,
            chest: b.chest + 12, headPitch: b.headPitch + 6
        })
        settle(load)
        var air = over(b, {
            lift: 0.62, drift: 0.42, torsoLean: 24,
            leadLegUp: -18, leadKnee: 42, leadToe: 28,
            rearLegUp: -34, rearKnee: 56, rearToe: 32,
            leadUp: 96, leadElbow: 8, leadIn: -10, leadOut: 5, leadRoll: 0.1,
            rearUp: 8, rearElbow: 48, rearOut: 26,
            blade: b.blade - 14, chestYaw: -16, headPitch: -4
        })
        var land = over(load, {
            drift: 0.28, leadKnee: 62, rearKnee: 60,
            chest: b.chest + 16
        })
        settle(land)
        return [{ t: 0, f: b },
                { t: 0.18, f: look(load, T) },
                { t: 0.46, ease: "out", f: look(air, T, 0.8) },
                { t: 0.66, ease: "in", f: look(land, T) },
                { t: 1, f: b }]
    }
},

{
    name: "jumpKick", label: "jumping side kick", group: "airborne",
    ms: 920, loop: false, amp: true,
    keys: function (T) {
        var b = ready(T)
        var load = over(b, {
            leadKnee: 58, rearKnee: 58, leadLegUp: 22, rearLegUp: -16,
            leadUp: 14, leadElbow: 86, rearUp: 16, rearElbow: 92,
            chest: b.chest + 12
        })
        settle(load)
        // In the air the body lies back behind the kicking leg and the other
        // knee folds up under it; the arms go out because there is nothing
        // else to balance against.
        var air = over(b, {
            lift: 0.7, drift: 0.3, torsoLean: -18,
            rearLegUp: 88, rearKnee: 6, rearToe: 24, rearLegOut: 10,
            leadLegUp: 46, leadKnee: 104, leadToe: 22,
            leadUp: 62, leadElbow: 58, leadOut: 40, leadIn: -8,
            rearUp: 30, rearElbow: 68, rearOut: 34,
            blade: b.blade - 8, headPitch: -2
        })
        var land = over(load, {
            drift: 0.16, leadKnee: 64, rearKnee: 60,
            chest: b.chest + 16
        })
        settle(land)
        return [{ t: 0, f: b },
                { t: 0.18, f: look(load, T) },
                { t: 0.48, ease: "out", f: look(air, T, 0.7) },
                { t: 0.68, ease: "in", f: look(land, T) },
                { t: 1, f: b }]
    }
},

// ------------------------------------------------------------ ground & recovery

{
    name: "knockdown", label: "knockdown / fall", group: "ground",
    ms: 950, loop: false, holds: true, amp: false,
    keys: function (T) {
        var b = ready(T)
        // The one move that does not come back to the stance: it ends on the
        // floor and STAYS there, because the next thing a knocked-down
        // figure does is get up, and that is the move after this one.
        var hit = over(b, {
            chest: b.chest - 16, headPitch: -14, torsoLean: -8,
            leadUp: 50, leadElbow: 38, leadOut: 40, leadIn: -20,
            rearUp: 46, rearElbow: 34, rearOut: 42, rearIn: -18,
            leadKnee: 34, rearKnee: 30, drift: -0.14,
            hand: "open"
        })
        settle(hit)
        var falling = over(hit, {
            torsoLean: -46, hipPitch: 14,
            leadKnee: 66, rearKnee: 54, leadLegUp: 30, rearLegUp: 8,
            drift: -0.3, lift: -0.62
        })
        return [{ t: 0, f: b },
                { t: 0.24, ease: "out", f: look(hit, T, 0.4) },
                { t: 0.58, ease: "in", f: look(falling, T, 0.3) },
                { t: 1, ease: "out", f: down(T) }]
    }
},

{
    name: "getUp", label: "get-up / recovery", group: "ground",
    ms: 1150, loop: false, amp: false,
    keys: function (T) {
        var b = ready(T)
        // Starts where the knockdown ended - the same frame, so the two are
        // one movement whichever way they are triggered - rolls onto a hand
        // and a knee, and stands up into the stance.
        var d = down(T)
        var roll = over(d, {
            torsoLean: -46, torsoRoll: 26, hipPitch: 34,
            leadUp: -18, leadElbow: 16, leadOut: 30, leadWrist: 22,
            leadKnee: 96, rearKnee: 82, leadLegUp: 48, rearLegUp: 26,
            headPitch: 10, lift: -0.88, drift: -0.28
        })
        // Up on one hand and one knee: the sheet's last panel.
        var braced = over(d, {
            torsoLean: 40, torsoRoll: 8, hipPitch: -14,
            leadUp: -14, leadElbow: 12, leadOut: 24, leadWrist: 24,
            rearUp: 18, rearElbow: 44, rearOut: 34, rearIn: -22,
            leadLegUp: 42, leadKnee: 102, rearLegUp: -32, rearKnee: 92,
            rearToe: 30, headPitch: -12, chest: 10, belly: 4,
            lift: -0.6, drift: -0.14
        })
        return [{ t: 0, f: d },
                { t: 0.3, f: roll },
                { t: 0.64, ease: "out", f: braced },
                { t: 1, ease: "out", f: b }]
    }
}

]

// Flat on the back, knees up: the frame the knockdown ends on and the get-up
// starts from. The whole figure is pitched back about the waist joint, which
// carries the hips and the legs with it, and dropped by whatever the waist
// stands at - so a tall character falls further than a short one and both
// end up on the floor.
function down(T) {
    var b = ready(T)
    return over(b, {
        torsoLean: -82, torsoRoll: 4, blade: b.blade - 10,
        hipPitch: 26, chest: -6, belly: -3,
        leadLegUp: 40, leadKnee: 66, rearLegUp: 24, rearKnee: 52,
        leadToe: 10, rearToe: 8, leadPivot: 0, rearPivot: 0,
        leadLegOut: 16, rearLegOut: 16,
        leadUp: 62, leadElbow: 24, leadOut: 55, leadIn: -25, leadRoll: 0.2,
        rearUp: 55, rearElbow: 28, rearOut: 50, rearIn: -22, rearRoll: 0.2,
        headPitch: 18, headYaw: 12, headRoll: 0,
        hand: "open",
        drift: -0.35,
        lift: T.downLift
    })
}

var MOVE_NAMES = MOVES.map(function (m) { return m.name })

function byName(name) {
    for (var i = 0; i < MOVES.length; i++)
        if (MOVES[i].name === name) return MOVES[i]
    return null
}

function known(name) { return byName(name) !== null }

// The name of the move a character in this set stands in when it is doing
// nothing else. What MoveSet falls back to when a one-shot finishes.
function restMove() { return "stance" }

// --- deriving a table ---------------------------------------------------------

// \a opts is what the animator was configured with: {intensity} always, and -
// when the caller has a body - {legHeight, hipHeight, footHeight, torsoDepth}
// in the body's own units, so the fall lands on the floor of THIS figure
// rather than of the one the numbers were written against.
//
// Everything is folded in here so poseAt() only ever reads finished numbers,
// exactly as gait.js and action.js do it.
function derive(name, opts) {
    var m = byName(name)
    if (m === null)
        return derive("stance", opts)
    opts = opts || {}
    var intensity = opts.intensity === undefined ? 0.5 : clamp(opts.intensity, 0, 1)

    // Where the waist stands, in leg heights, so a fall can put it on the
    // floor. Without a body it is the default figure's, which is what the
    // set was authored against.
    var downLift = -1.18
    if (opts.legHeight > 0) {
        var foot = opts.footHeight === undefined ? 0.5 : opts.footHeight
        var hip = opts.hipHeight === undefined ? 1.167 : opts.hipHeight
        var deep = opts.torsoDepth === undefined ? 1.25 : opts.torsoDepth
        downLift = -(foot + opts.legHeight + hip - deep * 0.55) / opts.legHeight
    }

    var T = { stance: STANCE, downLift: downLift }
    var keys = m.keys(T)

    // Effort is the SIZE of a move and its speed, never a different pose:
    // every key is mixed toward the ready stance, so a light jab is the same
    // jab shorter and a hard one the same jab further. Deliberately allowed
    // a little past 1 - an amateur throwing hard throws past the target -
    // and kept off the two ground moves, where the floor is not negotiable.
    if (m.amp) {
        var k = 0.85 + intensity * 0.34
        var rest = ready(T)
        keys = keys.map(function (key) {
            return { t: key.t, ease: key.ease, f: mixFrame(rest, key.f, k) }
        })
    }

    return {
        name: "martialarts",
        move: m.name,
        label: m.label,
        group: m.group,
        loop: m.loop === true,
        holds: m.holds === true,
        keys: keys,
        stanceFrame: ready(T),
        downLift: downLift,
        hand: keys[0].f.hand,
        // A harder move is a faster one. Bounded either way: the animation
        // is read frame by frame and something under a fifth of a second is
        // a flicker rather than a strike.
        cycleMs: Math.max(180, Math.round(m.ms / (0.78 + intensity * 0.44)))
    }
}

// --- the pose -----------------------------------------------------------------

// The pose \a table holds at phase \a t of its move, 0..1. Pure: the same
// answer the running move gives at that moment, which is what lets a sheet of
// stills be drawn from it and a suite assert on it.
//
// The wrist roll comes back as a FRACTION of a quarter turn rather than in
// degrees, because the degrees belong to the character (handRestRoll) and not
// to the move. Whoever applies the pose multiplies.
function poseAt(table, t) {
    return finish(frameAt(table, t))
}

// The frame at phase \a t: the two keys around it, mixed on the curve the
// later of the two arrives on.
//
// A LOOPING move wraps - phase 1.25 is phase 0.25 - and a ONE-SHOT does not:
// its phase 1 is the end of the move and has to stay there, which is the
// whole of how the knockdown ends up on the floor rather than back on its
// feet.
function frameAt(table, t) {
    var keys = table.keys
    t = table.loop ? t - Math.floor(t) : clamp(t, 0, 1)
    if (keys.length === 1)
        return keys[0].f
    var i = 0
    while (i < keys.length - 1 && t >= keys[i + 1].t) i++
    if (i >= keys.length - 1)
        return keys[keys.length - 1].f
    var a = keys[i], b = keys[i + 1]
    var span = b.t - a.t
    var u = span <= 0 ? 1 : clamp((t - a.t) / span, 0, 1)
    return mixFrame(a.f, b.f, shape(b.ease === undefined ? "inout" : b.ease, u))
}

// What the set offers, in the order the sheet lists it: enough for a UI to
// build a row of buttons without knowing anything about martial arts.
function moves() {
    return MOVES.map(function (m) {
        return { name: m.name, label: m.label, group: m.group,
                 loop: m.loop === true, holds: m.holds === true }
    })
}
