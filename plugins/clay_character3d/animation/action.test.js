// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the action model - standing, working, boxing.
//
//     node plugins/clay_character3d/animation/action.test.js
//
// What it exists to pin is the set of claims that a screenshot can only ever
// suggest: that a guard keeps both fists ABOVE the elbows and both elbows in
// against the ribs, that a punch reaches and comes back, that a working stroke
// actually travels, and that the two hands are never doing the same thing at
// the same moment. Every one of them was false in the cycles this model
// replaced, and none of them was visible as a number until the model existed.
const K = require('../../../labs/kits/kitcheck.js')

const A = K.load(__dirname, 'action.js', [
    'REST', 'BASES', 'BASE_NAMES', 'restPose', 'derive', 'poseAt',
    'punchAt', 'strokeAt', 'easeInOutQuad', 'easeOutCubic', 'ramp',
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
    eq('the hands are relaxed', r.hand, 'relax')
}

// ------------------------------------------------------------------- the shape
section('the punch curve snaps out and comes back slower')
{
    eq('it starts in the guard', A.punchAt(0), 0)
    eq('it ends in the guard', A.punchAt(1), 0)
    eq('it is fully out at the top', A.punchAt(0.37), 1)
    ok('it is more than half out a fifth of the way in', A.punchAt(0.22) > 0.5)
    // Out fast, back slow: the mid-point of the return is later than the
    // mid-point of the attack is early. A symmetric curve here is a
    // metronome, which is what the loop before this one was.
    const outMs = 0.32 - 0.10
    const backMs = 0.74 - 0.42
    ok('the return takes longer than the attack', backMs > outMs)
    ok('and there is a gap in the guard before the other hand goes',
       A.punchAt(0.9) === 0 && A.punchAt(0.05) === 0)
}

section('the working stroke never stops')
{
    eq('it starts at one end', A.strokeAt(0), 0)
    eq('it reaches the other half way', A.strokeAt(0.5), 1)
    eq('and it is back by the end', A.strokeAt(1), 0)
    ok('it is moving everywhere in between',
       A.strokeAt(0.26) !== A.strokeAt(0.24) && A.strokeAt(0.76) !== A.strokeAt(0.74))
}

// ---------------------------------------------------------------------- boxing
section('the guard is a guard: fists up, elbows down and in')
{
    const t = A.derive('fight', { intensity: 0.5 })
    const p = A.poseAt(t, 0)          // both hands in the guard

    for (const [name, a] of [['right', p.rightArm], ['left', p.leftArm]]) {
        const hand = handAt(a)
        const elbow = elbowAt(a)
        // THE failure this cycle had. The guard was written with the upper
        // arm 50-60 degrees forward, which puts the elbow up at chest height
        // and out in front - and an elbow that has left the ribs is a shrug.
        ok(name + ' elbow stays below the shoulder', elbow.y < -0.8)
        ok(name + ' fist is above its own elbow', hand.y > elbow.y)
        ok(name + ' fist is up around the shoulder', hand.y > -0.2)
        ok(name + ' fist is in front of the body', hand.z > 0.3)
        // ...but not at arm's length: that is a punch, not a guard.
        ok(name + ' fist is not out at reach', hand.z < 1.2)
    }
    ok('both fists are brought in across the chest',
       p.rightArm.upper[1] > 0 && p.leftArm.upper[1] < 0)
    ok('the palms face each other', t.guardRoll > 0.5)
    eq('the hands are closed', p.hand, 'fist')
}

section('the stance is bladed and staggered')
{
    const t = A.derive('fight', { intensity: 0.5 })
    const p = A.poseAt(t, 0)
    ok('the body is turned off square', Math.abs(p.torso[1]) > 10)
    ok('the lead leg is forward and the rear one is not',
       p.leftLeg.upper[0] < 0 && p.rightLeg.upper[0] > 0)
    ok('both knees are bent', p.leftLeg.lower[0] > 0 && p.rightLeg.lower[0] > 0)
    ok('and the feet are apart across the shoulders',
       p.rightLeg.upper[2] > 0 && p.leftLeg.upper[2] < 0)
    ok('the chest is rolled forward over the guard', p.chest[0] > 0)
    ok('the chin is tucked', p.head[0] > 0)
}

section('a punch is thrown, and only one at a time')
{
    const t = A.derive('fight', { intensity: 0.5 })
    // punchAt peaks over [0.42, 0.32] of the half-cycle; 0.37 of the first
    // half is 0.185 of the whole.
    const peakR = A.poseAt(t, 0.185)
    const peakL = A.poseAt(t, 0.685)

    const rOut = handAt(peakR.rightArm)
    const rGuard = handAt(peakR.leftArm)
    ok('the right hand reaches out past the left', rOut.z > rGuard.z + 0.8)
    ok('the right arm comes nearly straight', peakR.rightArm.lower[0] > -25)
    ok('the left arm stays folded in the guard', peakR.leftArm.lower[0] < -100)
    // The fist turns over on the way out. A straight thrown with the palm
    // still facing in is a slap.
    ok('the punching fist turns palm-down',
       Math.abs(peakR.rightArm.hand[1]) < Math.abs(peakR.leftArm.hand[1]) / 2)
    ok('the shoulders lead the hips into it',
       Math.abs(peakR.chest[1]) > Math.abs(peakR.torso[1] - t.blade))
    ok('the trunk turns the other way for the other hand',
       Math.sign(peakL.chest[1]) === -Math.sign(peakR.chest[1]))

    const lOut = handAt(peakL.leftArm)
    near('the left hand reaches exactly as far as the right did',
         lOut.z, rOut.z, 1e-9)
    ok('the hands are never both out', !(
        handAt(peakR.leftArm).z > 1.2 && rOut.z > 1.2))
    eq('the cycle is where it started when it ends',
       JSON.stringify(A.poseAt(t, 1)), JSON.stringify(A.poseAt(t, 0)))
}

section('intensity is speed and tightness, never a different pose')
{
    const calm = A.derive('fight', { intensity: 0 })
    const hard = A.derive('fight', { intensity: 1 })
    ok('a harder fight is a faster one', hard.cycleMs < calm.cycleMs)
    ok('and a tighter guard', hard.guardElbow > calm.guardElbow)
    eq('the blade does not change', hard.blade, calm.blade)
    eq('nor does the reach of the straight', hard.punchElbow, calm.punchElbow)
}

// ----------------------------------------------------------------------- work
section('working is work: hands low, in front, and actually moving')
{
    const t = A.derive('use', { intensity: 0.5, workHeight: 0.35 })
    const p = A.poseAt(t, 0.25)

    const hand = handAt(p.rightArm)
    const elbow = elbowAt(p.rightArm)
    // THE failure this cycle had: upper arms 45-65 degrees forward held for
    // the whole loop, so the hands hovered at chest height and nothing but
    // the elbows moved.
    ok('the elbow hangs near the ribs', elbow.y < -0.85)
    ok('the forearm is about level', Math.abs(hand.y - elbow.y) < 0.35)
    ok('the hands are out in front', hand.z > 0.7)
    ok('and below the shoulders', hand.y < -0.6)
    ok('the back is rounded over it', t.spineCurve > 0)
    ok('the head is down at the work', p.head[0] > 8)
    ok('the pelvis gives the belly bend back so the legs stay upright',
       Math.abs(p.hip[0] + p.belly[0]) < 1e-9)
    eq('the hands are loose', p.hand, 'relax')
}

section('the two hands work half a cycle apart')
{
    const t = A.derive('use', { intensity: 0.5, workHeight: 0.35 })
    // How far the two hands are from each other, at the moment they are
    // furthest apart. Measured on the HANDS rather than on one joint: most of
    // the stroke is in the elbow, so an upper-arm comparison reports a cycle
    // as synchronised that plainly is not.
    let apart = 0
    for (let i = 0; i < 16; i++) {
        const p = A.poseAt(t, i / 16)
        const r = handAt(p.rightArm), l = handAt(p.leftArm)
        apart = Math.max(apart, Math.hypot(r.z - l.z, r.y - l.y))
    }
    ok('they are never in step for long', apart > 0.3)
    const a = A.poseAt(t, 0.0), b = A.poseAt(t, 0.5)
    near('and each is where the other was, half a cycle later',
         a.rightArm.upper[0], b.leftArm.upper[0], 1e-9)
}

section('the stroke is big enough to see')
{
    const t = A.derive('use', { intensity: 0.5, workHeight: 0.35 })
    // Straight-line distance between the two extremes of the stroke, in
    // SEGMENT LENGTHS, so the claim reads the same on a child and on a giant.
    // Measured as a distance rather than along one axis: a working hand
    // presses down and lifts off as much as it reaches out, and an axis test
    // passes a cycle that only wobbles along the other one.
    const a = handAt(A.poseAt(t, 0).rightArm)
    const b = handAt(A.poseAt(t, 0.5).rightArm)
    const travel = Math.hypot(a.z - b.z, a.y - b.y)
    ok('the hand travels a third of a forearm', travel > 0.33)
    ok('but does not row', travel < 1.0)
}

section('workHeight lifts the work and stands the body up')
{
    const low = A.derive('use', { workHeight: 0 })
    const high = A.derive('use', { workHeight: 1 })
    ok('shoulder-height work lifts the upper arm', high.upper > low.upper)
    ok('and closes the elbow rather than only tilting the wrist',
       high.elbow < low.elbow)
    ok('reaching high straightens the back', high.lean < low.lean)
    ok('and lifts the head', high.headPitch < low.headPitch)

    const h = handAt(A.poseAt(high, 0).rightArm)
    const l = handAt(A.poseAt(low, 0).rightArm)
    ok('the hands end up higher', h.y > l.y)
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
}

process.exit(K.report('action model'))
