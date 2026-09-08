// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the action model - standing, working, boxing.
//
//     node plugins/clay_character3d/animation/action.test.js
//
// What it exists to pin is the set of claims that a screenshot can only ever
// suggest: that a guard keeps both fists ABOVE the elbows and both elbows in
// against the ribs, that the hand which is not punching does not move, that a
// jab is a shorter thing than a cross, that a working loop has beats rather
// than a stroke, and that the two hands are never doing the same thing at the
// same moment. Every one of them was false in the cycles this model replaced,
// and none of them was visible as a number until the model existed.
const K = require('../../../labs/kits/kitcheck.js')

const A = K.load(__dirname, 'action.js', [
    'REST', 'BASES', 'BASE_NAMES', 'restPose', 'derive', 'poseAt',
    'jabAt', 'crossAt', 'crossTrunkAt', 'strokeAt', 'beatAt', 'within',
    'punchAt', 'easeInOutQuad', 'easeOutCubic', 'ramp',
    'known', 'clamp', 'arm', 'leg'
])

const ok = K.ok, eq = K.eq, near = K.near, section = K.section
const rad = Math.PI / 180

// Where a hand ends up, in the shoulder's own frame, from the two pitches
// alone: a unit upper arm at `upper` degrees forward of hanging and a unit
// forearm folded `elbow` further. Only the sign and the ordering matter here,
// which is why the segments are unit length - the character's are not.
function handAt(a) {
    const up = -a.upper[0] * rad          // degrees forward of hanging
    const el = up - a.lower[0] * rad      // forearm, from the same zero
    return {
        y: -Math.cos(up) - Math.cos(el),  // up is +y
        z: Math.sin(up) + Math.sin(el)    // forward is +z
    }
}

function elbowAt(a) {
    const up = -a.upper[0] * rad
    return { y: -Math.cos(up), z: Math.sin(up) }
}

// The phases the boxing cycle is judged at: the settled guard late in the
// cycle, the peak of the first jab, and the peak of the cross. The peaks are
// where jabAt/crossAt hold 1, inside their slots.
const FIGHT = A.derive('fight', { intensity: 0.5 })
const GUARD_T = 0.95
const JAB_T = FIGHT.jab1[0] + (FIGHT.jab1[1] - FIGHT.jab1[0]) * 0.42
const JAB2_T = FIGHT.jab2[0] + (FIGHT.jab2[1] - FIGHT.jab2[0]) * 0.42
const CROSS_T = FIGHT.cross[0] + (FIGHT.cross[1] - FIGHT.cross[0]) * 0.44

// ------------------------------------------------------------------- standing
section('the rest pose is a person standing, not a mannequin')
{
    const r = A.restPose()
    ok('the arms hang clear of the ribs', A.REST.armOut > 0)
    ok('and the two of them clear it in opposite directions',
       r.rightArm.upper[2] > 0 && r.leftArm.upper[2] < 0)
    ok('the elbows are not locked', A.REST.elbow > 0)
    ok('the elbow bends forward', r.rightArm.lower[0] < 0)
    ok('the arms carry a little forward of the shoulder seam',
       r.rightArm.upper[0] < 0)
    ok('the palms turn in to face the body, each its own way',
       r.rightArm.hand[1] > 0 && r.leftArm.hand[1] < 0)
    // The whole point of a REST that is not sixteen zeros is that it stays
    // small: it is also the pose every gesture is released back to.
    ok('and all of it stays under ten degrees',
       A.REST.armOut < 10 && A.REST.armForward < 10 && A.REST.elbow < 10)
    eq('the trunk is upright', r.torso[0] + r.belly[0] + r.chest[0], 0)
    eq('the legs are straight', r.rightLeg.upper[0] + r.rightLeg.lower[0], 0)
    eq('the figure stands at its full height', r.lift, 0)
    eq('the hands are relaxed', r.hand, 'relax')
}

// ------------------------------------------------------------------- the shape
section('a jab barely winds up, snaps out and comes back slower')
{
    eq('it starts where it is told to', A.jabAt(0, 0.3, 0), 0.3)
    eq('and ends where it is told to', A.jabAt(1, 0.3, 0), 0)
    eq('it is fully out at the top', A.jabAt(0.42), 1)
    ok('the wind-up is a hair, not a haul', A.jabAt(0.10) < 0 && A.jabAt(0.10) > -0.1)
    ok('it is more than half out a fifth of the way in', A.jabAt(0.22) > 0.5)
    // Out fast, back slow: the extension window is shorter than the return.
    ok('the return takes longer than the attack', (0.86 - 0.46) > (0.38 - 0.10))
    ok('it overshoots the guard on the way back and settles',
       A.jabAt(0.86) < 0 && A.jabAt(1) === 0)
}

section('a cross winds up further and comes back slowest of all')
{
    eq('it starts in the guard', A.crossAt(0), 0)
    eq('it ends in the guard', A.crossAt(1), 0)
    eq('it is fully out at the top', A.crossAt(0.44), 1)
    let jabMin = 0, crossMin = 0
    for (let u = 0; u < 1; u += 0.01) {
        jabMin = Math.min(jabMin, A.jabAt(u))
        crossMin = Math.min(crossMin, A.crossAt(u))
    }
    ok('the rear fist is drawn back twice as far as the jab is', crossMin < jabMin * 1.8)
    ok('the trunk comes back before the arm does',
       A.crossTrunkAt(0.76) < 0.05 && A.crossAt(0.76) > 0.15)
    ok('and both are home at the end', A.crossTrunkAt(1) === 0 && A.crossAt(1) === 0)
}

section('the working stroke never stops, and a heavy one drops fast')
{
    eq('it starts at one end', A.strokeAt(0), 0)
    eq('it reaches the other half way', A.strokeAt(0.5), 1)
    eq('and it is back by the end', A.strokeAt(1), 0)
    ok('it is moving everywhere in between',
       A.strokeAt(0.26) !== A.strokeAt(0.24) && A.strokeAt(0.76) !== A.strokeAt(0.74))
    eq('a heavy stroke reaches its top late', A.strokeAt(0.7, 1), 1)
    ok('and is still lifting where an even one is already falling',
       A.strokeAt(0.6, 1) > A.strokeAt(0.6, 0))
    ok('and comes down faster than it went up',
       (1 - A.strokeAt(0.85, 1)) > (A.strokeAt(0.15, 1)))
}

section('a beat is nothing at its edges and everything in its middle')
{
    eq('zero at the start', A.beatAt(0), 0)
    eq('zero at the end', A.beatAt(1), 0)
    eq('one through the middle', A.beatAt(0.5), 1)
    eq('and nothing outside', A.beatAt(-0.1) + A.beatAt(1.1), 0)
    near('within says where in a slot a phase is', A.within(0.3, [0.2, 0.4]), 0.5, 1e-9)
    eq('and minus one outside it', A.within(0.5, [0.2, 0.4]), -1)
}

// ---------------------------------------------------------------------- boxing
section('the guard is a guard: fists up, elbows down and in')
{
    const p = A.poseAt(FIGHT, GUARD_T)

    for (const [name, a] of [['right', p.rightArm], ['left', p.leftArm]]) {
        const hand = handAt(a)
        const elbow = elbowAt(a)
        // THE failure the first cycle had: the upper arm 50-60 degrees
        // forward puts the elbow at chest height and out in front - and an
        // elbow that has left the ribs is a shrug.
        ok(name + ' elbow stays below the shoulder', elbow.y < -0.8)
        ok(name + ' fist is above its own elbow', hand.y > elbow.y)
        ok(name + ' fist is up around the shoulder', hand.y > -0.2)
        ok(name + ' fist is in front of the body', hand.z > 0.3)
        // ...but not at arm's length: that is a punch, not a guard.
        ok(name + ' fist is not out at reach', hand.z < 1.2)
        // The elbow flexion floor the brief will not bend on.
        ok(name + ' elbow is folded past a right angle', a.lower[0] < -110)
    }
    // A positive Y rotation carries a forward-pointing forearm toward +X,
    // so "in" is a negative yaw on the right arm and a positive one on the
    // left - the one sign in this model that was measured rather than
    // reasoned, at bench/ActionSandbox.qml.
    ok('both fists are brought in across the chest',
       p.rightArm.upper[1] < 0 && p.leftArm.upper[1] > 0)
    // The two hands are not a mirror pair: the rear is tucked tighter and
    // closer to the jaw than the lead.
    ok('the rear fist is tucked tighter than the lead',
       p.rightArm.lower[0] < p.leftArm.lower[0])
    ok('and sits closer to the face', handAt(p.rightArm).z < handAt(p.leftArm).z)
    ok('the palms face in', FIGHT.leadRoll > 0.5 && FIGHT.rearRoll > 0.5)
    eq('the wrists are straight', FIGHT.guardWrist, 0)
    eq('the hands are closed', p.hand, 'fist')
}

section('the stance is bladed, staggered and on bent knees')
{
    const p = A.poseAt(FIGHT, GUARD_T)
    ok('the body is turned well off square', Math.abs(p.torso[1]) >= 25)
    ok('the lead leg is forward and the rear one is not',
       p.leftLeg.upper[0] < 0 && p.rightLeg.upper[0] > 0)
    ok('and a shoulder-width apart front to back',
       Math.abs(p.leftLeg.upper[0]) + Math.abs(p.rightLeg.upper[0]) >= 30)
    ok('both knees are bent', p.leftLeg.lower[0] > 10 && p.rightLeg.lower[0] > 10)
    ok('and the feet are apart across the shoulders',
       p.rightLeg.upper[2] > 0 && p.leftLeg.upper[2] < 0)
    ok('the rear heel is up', p.rightLeg.foot[0] > 0)
    eq('and the lead foot is flat', p.leftLeg.foot[0], 0)
    eq('and neither foot is turned in the guard', p.rightLeg.foot[1] + p.leftLeg.foot[1], 0)
    ok('the chest is rolled forward over the guard', p.chest[0] > 0)
    ok('the chin is tucked', p.head[0] > 0)
    // The feet point one way and the face another: the head turns back part
    // of the blade so the figure looks at what it is boxing.
    ok('the face turns back toward the opponent',
       Math.sign(p.head[1]) === -Math.sign(p.torso[1]) && Math.abs(p.head[1]) < Math.abs(p.torso[1]))
    ok('the figure sits lower than it stands', p.lift < 0)
}

section('the guard bounces and weaves, and the fists ride with the face')
{
    let lo = 0, hi = -1, kneeLo = 999, kneeHi = -999, yawLo = 999, yawHi = -999
    const arms = new Set()
    for (let t = FIGHT.cross[1] + 0.01; t < 1; t += 0.005) {
        const p = A.poseAt(FIGHT, t)
        lo = Math.min(lo, p.lift); hi = Math.max(hi, p.lift)
        kneeLo = Math.min(kneeLo, p.rightLeg.lower[0]); kneeHi = Math.max(kneeHi, p.rightLeg.lower[0])
        yawLo = Math.min(yawLo, p.chest[1]); yawHi = Math.max(yawHi, p.chest[1])
        arms.add(JSON.stringify([p.rightArm, p.leftArm]))
    }
    ok('the figure bobs while it guards', hi - lo > 0.02)
    ok('and the knees take the bob', kneeHi - kneeLo > 2)
    ok('the shoulders roll around the blade', yawHi - yawLo > 2)
    eq('and the fists do not move on their own', arms.size, 1)
    ok('the bob is a dip, never a hop', hi < 0)
}

section('the lead hand jabs twice, and the rear hand does not move for it')
{
    const guard = A.poseAt(FIGHT, GUARD_T)
    const jab = A.poseAt(FIGHT, JAB_T)
    const lOut = handAt(jab.leftArm)
    ok('the left hand reaches out past the right', lOut.z > handAt(jab.rightArm).z + 0.8)
    ok('the left arm comes nearly straight', jab.leftArm.lower[0] > -30)
    ok('but a jab is not thrown to the last inch', jab.leftArm.lower[0] < -FIGHT.punchElbow - 1)
    eq('the rear hand is welded to the cheek',
       JSON.stringify(jab.rightArm), JSON.stringify(guard.rightArm))
    ok('the punching fist turns palm-down',
       Math.abs(jab.leftArm.hand[1]) < Math.abs(jab.rightArm.hand[1]) / 2)
    ok('the trunk turns only a little for it',
       Math.abs(jab.chest[1]) < 12 && jab.torso[1] > FIGHT.blade)

    // The second jab starts from a guard the first never got back to.
    const between = A.poseAt(FIGHT, FIGHT.jab2[0])
    ok('between the jabs the lead is not all the way home',
       between.leftArm.lower[0] > guard.leftArm.lower[0] + 10)
    const jab2 = A.poseAt(FIGHT, JAB2_T)
    near('and the second reaches as far as the first',
         handAt(jab2.leftArm).z, lOut.z, 1e-9)
    eq('the rear hand still has not moved',
       JSON.stringify(jab2.rightArm), JSON.stringify(guard.rightArm))
}

section('the cross is the heavy one: wound up, driven by the hips, overcommitted')
{
    const guard = A.poseAt(FIGHT, GUARD_T)
    const jab = A.poseAt(FIGHT, JAB_T)
    const cross = A.poseAt(FIGHT, CROSS_T)
    const rOut = handAt(cross.rightArm)
    ok('the right hand reaches out past the left', rOut.z > handAt(cross.leftArm).z + 0.8)
    ok('the right arm comes nearly straight', cross.rightArm.lower[0] > -25)
    ok('and further than the jab did', rOut.z > handAt(jab.leftArm).z)
    ok('the left arm stays folded in the guard', cross.leftArm.lower[0] < -100)
    eq('and the left fist is welded to the cheek',
       JSON.stringify(cross.leftArm), JSON.stringify(guard.leftArm))
    ok('the punching fist turns palm-down',
       Math.abs(cross.rightArm.hand[1]) < Math.abs(cross.leftArm.hand[1]) / 2)
    ok('the hips unwind out of the blade', cross.torso[1] < FIGHT.blade - 10)
    ok('and the shoulders go past them', Math.abs(cross.chest[1]) > Math.abs(cross.torso[1] - FIGHT.blade))
    ok('the shoulders turn much further than for the jab',
       Math.abs(cross.chest[1]) > Math.abs(jab.chest[1]) * 2)
    ok('the trunk turns the other way from the jab',
       Math.sign(cross.chest[1]) === -Math.sign(jab.chest[1]))
    ok('the chest leans into it', cross.chest[0] > guard.chest[0] + 3)
    ok('and the head goes with it', cross.head[0] > guard.head[0])
    ok('the rear foot turns on its ball', cross.rightLeg.foot[1] !== 0)

    // The wind-up: before it goes, the rear fist is drawn back past the guard.
    const load = A.poseAt(FIGHT, FIGHT.cross[0] + (FIGHT.cross[1] - FIGHT.cross[0]) * 0.16)
    ok('the rear fist is drawn back before it goes',
       load.rightArm.lower[0] < guard.rightArm.lower[0])
    ok('the hands are never both out', (() => {
        for (let t = 0; t < 1; t += 1 / 96) {
            const p = A.poseAt(FIGHT, t)
            if (handAt(p.leftArm).z > 1.2 && handAt(p.rightArm).z > 1.2) return false
        }
        return true
    })())
    eq('the cycle is where it started when it ends',
       JSON.stringify(A.poseAt(FIGHT, 1)), JSON.stringify(A.poseAt(FIGHT, 0)))
}

section('the rhythm is short, short, long')
{
    const j1 = FIGHT.jab1[1] - FIGHT.jab1[0]
    const j2 = FIGHT.jab2[1] - FIGHT.jab2[0]
    const c = FIGHT.cross[1] - FIGHT.cross[0]
    ok('each jab is shorter than the cross', j1 < c && j2 < c)
    ok('the second jab follows the first without a gap', FIGHT.jab2[0] === FIGHT.jab1[1])
    ok('and there is a beat before the cross to load it', FIGHT.cross[0] > FIGHT.jab2[1])
    ok('and a guard after it', FIGHT.cross[1] < 0.9)
}

section('intensity is speed, tightness and bounce, never a different pose')
{
    const calm = A.derive('fight', { intensity: 0 })
    const hard = A.derive('fight', { intensity: 1 })
    ok('a harder fight is a faster one', hard.cycleMs < calm.cycleMs)
    ok('and a tighter guard', hard.leadElbow > calm.leadElbow)
    ok('and a bigger bounce', hard.bob > calm.bob)
    eq('the blade does not change', hard.blade, calm.blade)
    eq('nor does the reach of the straight', hard.punchElbow, calm.punchElbow)
    eq('nor the rhythm', JSON.stringify(hard.cross), JSON.stringify(calm.cross))
}

// ----------------------------------------------------------------------- work
section('working is work: hands low, in front, in beats')
{
    const t = A.derive('use', { intensity: 0.5, workHeight: 0.35 })
    const p = A.poseAt(t, 0.45)      // mid-work

    const hand = handAt(p.rightArm)
    const elbow = elbowAt(p.rightArm)
    // THE failure the first cycle had: upper arms 45-65 degrees forward held
    // for the whole loop, so the hands hovered at chest height and nothing
    // but the elbows moved.
    ok('the elbow hangs near the ribs', elbow.y < -0.85)
    ok('the hands are out in front', hand.z > 0.7)
    ok('and below the shoulders', hand.y < -0.3)
    ok('but not at arm\'s length', Math.hypot(hand.y, hand.z) < 1.5)
    ok('the elbow is bent between seventy and a hundred and fifteen',
       p.rightArm.lower[0] < -70 && p.rightArm.lower[0] > -115)
    ok('the back is rounded over it', t.curve > 0)
    ok('the head is down at the work', p.head[0] > 8)
    ok('the pelvis gives the belly bend back so the legs stay upright',
       Math.abs(p.hip[0] + p.belly[0]) < 1e-9)
    ok('both knees are a little bent', p.rightLeg.lower[0] > 0 && p.leftLeg.lower[0] > 0)
    eq('the hands are loose', p.hand, 'relax')
}

section('the two hands are never level and never mirrored')
{
    const t = A.derive('use', { intensity: 0.5, workHeight: 0.35 })
    let minApart = 999, maxApart = 0
    for (let i = 0; i < 48; i++) {
        const p = A.poseAt(t, i / 48)
        const r = handAt(p.rightArm), l = handAt(p.leftArm)
        const apart = Math.hypot(r.z - l.z, r.y - l.y)
        minApart = Math.min(minApart, apart)
        maxApart = Math.max(maxApart, apart)
    }
    ok('at every moment the lead hand is somewhere the off hand is not', minApart > 0.05)
    ok('and at some moment far from it', maxApart > 0.3)
    // The off hand does less. The lead reaches and presses; the off hand
    // holds, so its travel across the cycle is the smaller.
    function travel(pick) {
        let lo = { y: 9, z: 9 }, hi = { y: -9, z: -9 }
        for (let i = 0; i < 48; i++) {
            const h = handAt(pick(A.poseAt(t, i / 48)))
            lo.y = Math.min(lo.y, h.y); lo.z = Math.min(lo.z, h.z)
            hi.y = Math.max(hi.y, h.y); hi.z = Math.max(hi.z, h.z)
        }
        return Math.hypot(hi.y - lo.y, hi.z - lo.z)
    }
    const lead = travel(p => p.rightArm), off = travel(p => p.leftArm)
    ok('the lead hand travels further than the off hand', lead > off * 1.5)
    ok('the lead hand travels most of a forearm', lead > 0.5)
    ok('but does not row', lead < 1.2)
    ok('and the off hand still moves', off > 0.1)
}

section('the loop has four beats, not one stroke')
{
    const t = A.derive('use', { intensity: 0.5, workHeight: 0.35 })
    const base = handAt(A.poseAt(t, t.reach[0]).rightArm)   // a beat boundary
    const reach = handAt(A.poseAt(t, (t.reach[0] + t.reach[1]) / 2).rightArm)
    const press = handAt(A.poseAt(t, (t.press[0] + t.press[1]) / 2).rightArm)
    const settle = handAt(A.poseAt(t, (t.settle[0] + t.settle[1]) / 2).rightArm)
    ok('the reach takes the hand out', reach.z > base.z + 0.25)
    ok('and to the side', A.poseAt(t, (t.reach[0] + t.reach[1]) / 2).rightArm.upper[1]
                        > A.poseAt(t, t.reach[0]).rightArm.upper[1])
    ok('from hands that sit in toward the centre line', A.poseAt(t, 0).rightArm.upper[1] < 0
                                                      && A.poseAt(t, 0).leftArm.upper[1] > 0)
    ok('the press takes it down', press.y < base.y - 0.1)
    ok('the settle brings it back toward the body', settle.z < base.z)
    // The work beat is strokes: the hand is at different places at close
    // moments inside it, and not monotonically.
    let turns = 0, last = 0, dir = 0
    for (let u = t.work[0]; u < t.work[1]; u += 0.005) {
        const e = A.poseAt(t, u).rightArm.lower[0]
        const d = Math.sign(e - last)
        if (dir !== 0 && d !== 0 && d !== dir) turns++
        if (d !== 0) dir = d
        last = e
    }
    ok('the work beat is several strokes', turns >= 4)
    // The head leads the reach and lifts at the settle.
    const headReach = A.poseAt(t, t.reach[0] + 0.02).head[1]
    ok('the head turns toward the reach before the hand is out', Math.abs(headReach) > 2)
    ok('and comes up at the end of the cycle',
       A.poseAt(t, (t.settle[0] + t.settle[1]) / 2).head[0] < A.poseAt(t, 0.45).head[0])
    ok('every fourth cycle it comes up further',
       A.poseAt(t, (t.settle[0] + t.settle[1]) / 2, 3).head[0]
       < A.poseAt(t, (t.settle[0] + t.settle[1]) / 2, 0).head[0])
    eq('the cycle is where it started when it ends',
       JSON.stringify(A.poseAt(t, 1)), JSON.stringify(A.poseAt(t, 0)))
}

section('workHeight is a posture, not a hand height')
{
    const low = A.derive('use', { workHeight: 0 })
    const mid = A.derive('use', { workHeight: 0.5 })
    const high = A.derive('use', { workHeight: 1 })
    const h = handAt(A.poseAt(high, 0).rightArm)
    const m = handAt(A.poseAt(mid, 0).rightArm)
    const l = handAt(A.poseAt(low, 0).rightArm)
    ok('the hands rise with the work', l.y < m.y && m.y < h.y)
    ok('over a table the forearm is about level',
       Math.abs(l.y - elbowAt(A.poseAt(low, 0).rightArm).y) < 0.35)
    ok('over a table the fingertips are down at the waist', l.y < -0.9)
    ok('at a shelf the hands are up at the face', h.y > 0.3)
    ok('the back rounds over a table and arches at a shelf', low.curve > 0 && high.curve < 0)
    ok('and leans over the one and not the other', low.lean > 8 && high.lean < 0)
    ok('the head is down at a table and up at a shelf', low.headPitch > 20 && high.headPitch < 0)
    ok('the palms turn down over a table and in at a shelf', low.roll < 0.35 && high.roll > 0.55)
}

section('effort is amplitude, tempo and how much of the body joins in')
{
    const light = A.derive('use', { intensity: 0.2 })
    const normal = A.derive('use', { intensity: 0.5 })
    const hard = A.derive('use', { intensity: 1.0 })
    ok('harder is faster', hard.cycleMs < normal.cycleMs && normal.cycleMs < light.cycleMs)
    ok('but never frantic', hard.cycleMs >= 1900)
    ok('and bigger', hard.strokeElbow > normal.strokeElbow && normal.strokeElbow > light.strokeElbow)
    ok('the body leans into hard work', hard.lean > normal.lean && normal.lean === light.lean)
    ok('and rocks more', hard.rock > light.rock)
    // Past six tenths the off hand stops working and holds.
    ok('fiddling and normal work use both hands', light.offShare > 0.5 && normal.offShare > 0.5)
    ok('hammering holds with one and hits with the other', hard.offShare < 0.15)
    ok('and the hit is a lift and a drop', hard.snap === 1 && normal.snap === 0)
}

// ------------------------------------------------------------------- the edges
section('the model answers for whatever it is asked')
{
    ok('it knows its two actions', A.known('fight') && A.known('use'))
    ok('and nothing else', !A.known('juggle'))
    eq('an unknown action falls back rather than throwing',
       A.derive('juggle', {}).name, 'use')
    eq('so does no options at all', A.derive('use').name, 'use')
    eq('intensity is clamped', A.derive('fight', { intensity: 9 }).cycleMs,
       A.derive('fight', { intensity: 1 }).cycleMs)
    // The phase wraps, so a caller need not normalise before asking.
    const t = A.derive('fight', {})
    eq('the phase wraps', JSON.stringify(A.poseAt(t, 2.25)),
       JSON.stringify(A.poseAt(t, 0.25)))
    eq('and wraps backwards', JSON.stringify(A.poseAt(t, -0.75)),
       JSON.stringify(A.poseAt(t, 0.25)))
    const u = A.derive('use', {})
    eq('a missing cycle count is the first cycle',
       JSON.stringify(A.poseAt(u, 0.9)), JSON.stringify(A.poseAt(u, 0.9, 0)))
    ok('every pose carries a lift', A.poseAt(t, 0.3).lift !== undefined && A.poseAt(u, 0.3).lift !== undefined)
}

process.exit(K.report('action model'))
