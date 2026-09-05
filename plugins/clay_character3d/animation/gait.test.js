// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the gait model.
//
//     node plugins/clay_character3d/animation/gait.test.js
//
// The model is Qt-free (`.pragma library`, no Qt types, no clock) so this runs
// in a second with no engine. The claim it exists to pin: the all-neutral gait
// is, to the digit, the walk and run the framework had before gait.js - that
// is the only way "without changing the current neutral walk/run" is an
// assertion rather than a hope. After that it pins the algebra of compose(),
// the shape of every preset and build zone, and that poseAt() replays the
// cycle the way the animation plays it.
const K = require('../../../labs/kits/kitcheck.js')

const G = K.load(__dirname, 'gait.js', [
    'FACTORS', 'FACTOR_NAMES', 'BASES', 'PRESETS', 'PRESET_NAMES',
    'neutral', 'compose', 'scaled', 'emotionFactors', 'canonicalEmotion',
    'buildFactors', 'presetFactors', 'presetKnown', 'derive', 'strideLength',
    'speedFor', 'poseAt', 'easeInOutQuad', 'liftAt', 'ankleZ', 'spineFrom',
    'BUILD'
])
G.BUILD_SOFT = G.BUILD.soft

const ok = K.ok, eq = K.eq, near = K.near, section = K.section
const rad = Math.PI / 180

// ---------------------------------------------------------- neutral == legacy
section('the neutral gait is the legacy walk, digit for digit')
{
    // WalkAnim before this file: the constants and the formulas that derived
    // the rest from them.
    const fwd = 25, back = 20
    const swing = (fwd + back) / 45
    const legacyWalk = {
        hipFwd: fwd, hipBack: back,
        kneeLift: 25 + swing * 20, kneeExtend: 10 + swing * 5,
        footUp: 20, footDown: 25,
        armFwd: fwd * 0.6, armBack: fwd * 0.6 * 0.9,
        elbow: 10, lean: 0, cycleMs: 800
    }
    const t = G.derive('walk', G.neutral())
    for (const k of Object.keys(legacyWalk))
        near('walk.' + k, t[k], legacyWalk[k], 1e-9)
    eq('walk has no lift', t.bounce, 0)
    eq('walk has no sway', t.sway, 0)
    eq('walk has no rock', t.rock, 0)
    eq('walk holds the head level', t.headPitch, 0)
    eq('walk has no waist lean', t.waistLean, 0)

    // The speed is NOT the legacy one on purpose: it is the planted foot's
    // real travel (knee included) over the step, where the old cycle used
    // the straight-leg arc and the feet skated by a fifth.
    const legHeight = 5.333, L = legHeight / 2
    const start = G.ankleZ(-fwd, legacyWalk.kneeExtend, L, L)
    const end = G.ankleZ(back, legacyWalk.kneeLift, L, L)
    near('walk speed is the stance foot travel over the step',
         G.speedFor(t, legHeight), (start - end) * 2 / 0.8, 1e-9)
    ok('the old straight-leg speed over-reached', G.speedFor(t, legHeight)
       > legHeight * (Math.sin(fwd * rad) + Math.sin(back * rad)) * 2 / 0.8)
}

section('the neutral gait is the legacy run, digit for digit')
{
    const fwd = 55, back = 45
    const swing = (fwd + back) / 70
    const legacyRun = {
        hipFwd: fwd, hipBack: back,
        kneeLift: 70 + swing * 40, kneeExtend: 10 + swing * 5,
        footUp: 25, footDown: 35,
        armFwd: fwd * 1.0, armBack: back * 1.0,
        elbow: 70, lean: 12, cycleMs: 450
    }
    const t = G.derive('run', G.neutral())
    for (const k of Object.keys(legacyRun))
        near('run.' + k, t[k], legacyRun[k], 1e-9)
    eq('run lean is whole-body, not at the waist', t.waistLean, 0)
    const L = 5.333 / 2
    near('run speed is the stance foot travel over the step', G.speedFor(t, 5.333),
         (G.ankleZ(-fwd, legacyRun.kneeExtend, L, L) - G.ankleZ(back, legacyRun.kneeLift, L, L)) * 2 / 0.45, 1e-9)
    ok('the old straight-leg run speed over-shot', G.speedFor(t, 5.333)
       < 5.333 * (Math.sin(fwd * rad) + Math.sin(back * rad)) * 2 / 0.45)
}

section('the planted foot does not slide: net slip is zero by construction')
{
    for (const [name, base, f] of [['walk', 'walk', null], ['run', 'run', null],
                                   ['sneak', 'walk', G.compose([G.presetFactors('sneak')])],
                                   ['march', 'walk', G.compose([G.presetFactors('march')])]]) {
        const t = G.derive(base, f), leg = 5.333, L = leg / 2
        const v = G.speedFor(t, leg), phaseS = t.cycleMs / 2000
        const p0 = G.poseAt(t, 0), p1 = G.poseAt(t, 0.4999999)
        // the left leg is planted in the first phase: forward at t=0, back at t=0.5
        const travel = G.ankleZ(p0.leftLeg.upper, p0.leftLeg.lower, L, L)
                     - G.ankleZ(p1.leftLeg.upper, p1.leftLeg.lower, L, L)
        near(name + ': body travel per step equals stance foot travel', v * phaseS, travel, 1e-3)
        // and the hip moves linearly, so mid-step it is exactly halfway
        const pm = G.poseAt(t, 0.25)
        near(name + ': hip is halfway at mid-step', pm.leftLeg.upper, (-t.hipFwd + t.hipBack) / 2, 1e-9)
    }
    eq('upperRatio defaults to a half', G.strideLength(G.derive('walk', null), 4), G.strideLength(G.derive('walk', null), 4, 0.5))
    ok('a longer thigh changes the stride', G.strideLength(G.derive('walk', null), 4, 0.6) !== G.strideLength(G.derive('walk', null), 4, 0.5))
}

section('a factor lean bends at the waist, a base lean does not')
{
    const w = G.derive('walk', { lean: 8 })
    eq('walk: the trunk carries it', w.lean, 8)
    eq('walk: it is all waist', w.waistLean, 8)
    // What the legs end up doing: belly + hip is where the pelvis points, and
    // under a factor lean that must be straight up.
    near('walk: the legs stay planted', w.bellyLean + w.hipLean, 0, 1e-12)
    const r = G.derive('run', { lean: 8 })
    eq('run: the trunk carries base plus factor', r.lean, 20)
    eq('run: only the factor is at the waist', r.waistLean, 8)
    near('run: the legs tip with the base lean', r.bellyLean + r.hipLean, 12, 1e-12)
    near('run neutral: the legs tip the whole 12',
         G.derive('run', null).bellyLean + G.derive('run', null).hipLean, 12, 1e-12)
    near('walk neutral: nothing tips at all',
         G.derive('walk', null).bellyLean + G.derive('walk', null).hipLean, 0, 1e-12)
}

section('derive without factors, and with nonsense, is neutral')
{
    const n = G.derive('walk', G.neutral())
    eq('null factors', JSON.stringify(G.derive('walk', null)), JSON.stringify(n))
    eq('unknown base falls back to walk', G.derive('crawl', null).base, 'walk')
    eq('NaN factor is ignored', G.derive('walk', { tempo: NaN }).cycleMs, 800)
    eq('compose with no layers is neutral',
       JSON.stringify(G.compose([])), JSON.stringify(G.neutral()))
    eq('compose skips null layers',
       JSON.stringify(G.compose([null, undefined])), JSON.stringify(G.neutral()))
}

// ------------------------------------------------------------------ algebra
section('compose: products multiply, sums add, order does not matter')
{
    const a = { tempo: 1.2, lean: 5 }
    const b = { tempo: 0.5, lean: -3, sway: 4 }
    const ab = G.compose([a, b]), ba = G.compose([b, a])
    near('tempo multiplies', ab.tempo, 0.6, 1e-12)
    near('lean adds', ab.lean, 2, 1e-12)
    near('missing factor stays neutral', ab.stride, 1, 1e-12)
    eq('commutative', JSON.stringify(ab), JSON.stringify(ba))
    eq('unknown keys are ignored', G.compose([{ wingspan: 3 }]).wingspan, undefined)
}

section('compose clamps once, to the factor ranges')
{
    const f = G.compose([{ tempo: 100 }, { lean: -900 }, { bounce: 5 }, { kneeLift: 0 }])
    eq('tempo max', f.tempo, G.FACTORS.tempo.max)
    eq('lean min', f.lean, G.FACTORS.lean.min)
    eq('bounce max', f.bounce, G.FACTORS.bounce.max)
    eq('kneeLift min', f.kneeLift, G.FACTORS.kneeLift.min)
    // The joint limits are the second line: a legal factor vector can still
    // ask for more than a knee has.
    const t = G.derive('run', { kneeLift: 2 })
    eq('knee never past 150', t.kneeLift, 150)
    const u = G.derive('walk', { tempo: 0.4 })
    eq('cycle never longer than 2 s', u.cycleMs, 2000)
}

section('scaled() pulls a vector toward neutral')
{
    const v = G.scaled({ tempo: 2, lean: 10 }, 0.5)
    near('mul factor halfway', v.tempo, 1.5, 1e-12)
    near('add factor halfway', v.lean, 5, 1e-12)
    const z = G.scaled({ tempo: 2, lean: 10 }, 0)
    near('weight 0 is neutral (mul)', z.tempo, 1, 1e-12)
    near('weight 0 is neutral (add)', z.lean, 0, 1e-12)
}

// ------------------------------------------------------------------ sources
section('emotions: the same vocabulary the face uses')
{
    eq('happy', G.canonicalEmotion('happy'), 'happy')
    eq('joy is happy', G.canonicalEmotion('JOY'), 'happy')
    eq('sadness is sad', G.canonicalEmotion('sadness'), 'sad')
    eq('anger is angry', G.canonicalEmotion('anger'), 'angry')
    eq('neutral is empty', G.canonicalEmotion('neutral'), '')
    eq('empty is empty', G.canonicalEmotion(''), '')
    eq('null is empty', G.canonicalEmotion(null), '')
    eq('unknown is empty', G.canonicalEmotion('bored'), '')
    eq('no emotion, no layer', G.emotionFactors(''), null)

    const n = G.derive('walk', null)
    const sad = G.derive('walk', G.compose([G.emotionFactors('sad')]))
    const happy = G.derive('walk', G.compose([G.emotionFactors('happy')]))
    const angry = G.derive('walk', G.compose([G.emotionFactors('angry')]))
    ok('sad is slower', sad.cycleMs > n.cycleMs)
    ok('sad covers less ground', G.speedFor(sad, 5) < G.speedFor(n, 5))
    ok('sad hangs the head', sad.headPitch > 0)
    ok('sad slumps', sad.lean > 0)
    ok('sad drags the feet', sad.kneeLift < n.kneeLift)
    ok('happy is quicker', happy.cycleMs < n.cycleMs)
    ok('happy bounces', happy.bounce > 0)
    ok('happy swings the arms', happy.armFwd > n.armFwd)
    ok('happy lifts the chin', happy.headPitch < 0)
    ok('angry leans in', angry.lean > 0)
    ok('angry bends the elbows', angry.elbow > n.elbow)
    ok('angry is quicker', angry.cycleMs < n.cycleMs)
    ok('angry carries the arms in front', angry.armFwd > n.armFwd && angry.armBack < n.armBack)
    ok('happy swings the arms further than angry', happy.armFwd + happy.armBack > angry.armFwd + angry.armBack)
}

section('armOut carries the upper arms off the ribs, and only that')
{
    const n = G.derive('walk', null)
    eq('neutral holds them against the body', n.armOut, 0)
    const f = G.derive('walk', G.compose([{ armOut: 14 }]))
    eq('the factor arrives', f.armOut, 14)
    near('and moves nothing else', f.armFwd, n.armFwd, 1e-12)
    near('nor the reach behind', f.armBack, n.armBack, 1e-12)
    eq('never adducts past the body', G.derive('walk', G.compose([{ armOut: -30 }])).armOut, 0)

    // Signed by the side, not by the phase: both arms go OUT, and they stay
    // out for the whole cycle.
    for (const t of [0, 0.2, 0.5, 0.75]) {
        const p = G.poseAt(f, t)
        near('t=' + t + ': the right arm rolls +out', p.rightArm.out, 14, 1e-12)
        near('t=' + t + ': the left arm rolls -out', p.leftArm.out, -14, 1e-12)
    }
    const p0 = G.poseAt(G.derive('walk', null), 0)
    eq('a neutral walk keeps them in', p0.rightArm.out, 0)
    eq('and on the other side too', p0.leftArm.out, 0)
}

section('armForward shifts the swing, keeps its amplitude')
{
    const n = G.derive('walk', null)
    const f = G.derive('walk', { armForward: 20 })
    near('forward reach grows', f.armFwd, n.armFwd + 20, 1e-12)
    near('back reach shrinks', f.armBack, n.armBack - 20, 1e-12)
    near('amplitude unchanged', f.armFwd + f.armBack, n.armFwd + n.armBack, 1e-12)
    eq('neutral is zero', G.neutral().armForward, 0)
}

section('build: zero effect at every default')
{
    eq('all defaults is no layer',
       G.buildFactors({ maturity: 0.5, femininity: 0.5, mass: 0.5, muscle: 0.5 }), null)
    eq('missing fields are defaults', G.buildFactors({}), null)
    eq('no build, no layer', G.buildFactors(null), null)
    eq('adult zone is neutral (0.4)', G.buildFactors({ maturity: 0.4 }), null)
    eq('adult zone is neutral (0.75)', G.buildFactors({ maturity: 0.75 }), null)
}

section('build: each slider leaves neutral in the direction it should')
{
    const n = G.derive('walk', null)
    const child = G.derive('walk', G.buildFactors({ maturity: 0 }))
    ok('child is quicker', child.cycleMs < n.cycleMs)
    ok('child lifts the knees', child.kneeLift > n.kneeLift)
    ok('child bounces', child.bounce > 0)
    const old = G.derive('walk', G.buildFactors({ maturity: 1 }))
    ok('elderly is slower', old.cycleMs > n.cycleMs)
    ok('elderly shuffles', old.kneeLift < n.kneeLift)
    ok('elderly stoops', old.lean > 0 && old.headPitch > 0)
    ok('elderly swings less', old.armFwd < n.armFwd)
    const half = G.derive('walk', G.buildFactors({ maturity: 0.875 }))
    ok('elderly fades in', half.cycleMs > n.cycleMs && half.cycleMs < old.cycleMs)
    const fem = G.derive('walk', G.buildFactors({ femininity: 1 }))
    ok('feminine sways', fem.sway > 0)
    ok('feminine swings the arms less', fem.armFwd < n.armFwd)
    eq('feminine does not rock', fem.rock, 0)
    const masc = G.derive('walk', G.buildFactors({ femininity: 0 }))
    ok('masculine rocks a little', masc.rock > 0)
    eq('masculine does not sway', masc.sway, 0)
    const heavy = G.derive('walk', G.buildFactors({ mass: 1 }))
    ok('heavy is slower', heavy.cycleMs > n.cycleMs)
    ok('heavy rocks', heavy.rock > masc.rock)
    ok('heavy takes shorter steps', heavy.hipFwd < n.hipFwd)
    const light = G.derive('walk', G.buildFactors({ mass: 0 }))
    ok('light is a touch quicker', light.cycleMs < n.cycleMs)
    const fit = G.derive('walk', G.buildFactors({ muscle: 1 }))
    ok('athletic swings the arms', fit.armFwd > n.armFwd)
    const soft = G.derive('walk', G.buildFactors({ muscle: 0 }))
    ok('soft slumps', soft.lean > 0)
}

section('build: subtle, so the sliders stay a body and not a costume')
{
    // Whatever the sliders say, a build alone never turns a walk into a
    // sprint or a crawl, and never asks for an angle the joints refuse.
    const corners = []
    for (const m of [0, 0.5, 1]) for (const f of [0, 0.5, 1])
        for (const w of [0, 0.5, 1]) for (const u of [0, 0.5, 1])
            corners.push({ maturity: m, femininity: f, mass: w, muscle: u })
    let within = true
    for (const c of corners) {
        const t = G.derive('walk', G.buildFactors(c))
        if (t.cycleMs < 500 || t.cycleMs > 1400) within = false
        if (t.kneeLift > 100 || t.lean > 20 || t.headPitch > 25) within = false
    }
    ok('every slider corner stays inside a walk', within)
}

section('presets: every name resolves, unknown names do not pretend to')
{
    for (const name of G.PRESET_NAMES)
        ok('preset ' + name + ' is a factor vector', G.presetFactors(name) !== null)
    eq('neutral preset changes nothing',
       JSON.stringify(G.derive('walk', G.compose([G.presetFactors('neutral')]))),
       JSON.stringify(G.derive('walk', null)))
    eq('empty name is known (means none)', G.presetKnown(''), true)
    eq('unknown name is not known', G.presetKnown('moonwalk'), false)
    eq('unknown name is no layer', G.presetFactors('moonwalk'), null)
    eq('prototype names are not presets', G.presetKnown('constructor'), false)
    eq('cheerful is the happy emotion', G.presetFactors('cheerful'), G.emotionFactors('happy'))
    eq('dejected is the sad emotion', G.presetFactors('dejected'), G.emotionFactors('sad'))
    eq('furious is the angry emotion', G.presetFactors('furious'), G.emotionFactors('angry'))
}

section('presets: each one derives to a legal cycle for walk and run')
{
    let legal = true
    for (const name of G.PRESET_NAMES) for (const base of ['walk', 'run']) {
        const t = G.derive(base, G.compose([G.presetFactors(name)]))
        for (const k of Object.keys(t))
            if (k !== 'base' && !isFinite(t[k])) legal = false
        if (t.kneeLift < t.kneeExtend) legal = false
        if (t.cycleMs < 250 || t.cycleMs > 2000) legal = false
    }
    ok('all presets x both bases are finite and inside the limits', legal)
    const sneak = G.derive('walk', G.compose([G.presetFactors('sneak')]))
    ok('sneak lifts the knees high and slow', sneak.kneeLift > 60 && sneak.cycleMs > 1000)
    const march = G.derive('walk', G.compose([G.presetFactors('march')]))
    ok('march straightens the arms', march.elbow === 0)
}

section('layers stack the way an author reads them')
{
    // "elderly, a fifth quicker": the preset's tempo times 1.2.
    const f = G.compose([G.presetFactors('elderly'), { tempo: 1.2 }])
    near('elderly x 1.2', f.tempo, G.PRESETS.elderly.tempo * 1.2, 1e-12)
    // A sad, heavy character: both slow it down.
    const both = G.compose([G.buildFactors({ mass: 1 }), G.emotionFactors('sad')])
    ok('sad and heavy is slower than either',
       both.tempo < G.buildFactors({ mass: 1 }).tempo && both.tempo < G.emotionFactors("sad").tempo)
}

// ---------------------------------------------------------------- the cycle
section('poseAt replays the cycle the animation plays')
{
    const t = G.derive('walk', G.compose([{ bounce: 0.05, sway: 8, rock: 5, lean: 6, headPitch: -4 }]))
    const p0 = G.poseAt(t, 0), p1 = G.poseAt(t, 1), pHalf = G.poseAt(t, 0.5)
    eq('t=1 is t=0', JSON.stringify(p1), JSON.stringify(p0))
    // Phase boundaries hold the cycle's key poses exactly.
    near('t=0 right hip is back', p0.rightLeg.upper, t.hipBack, 1e-12)
    near('t=0 left hip is forward', p0.leftLeg.upper, -t.hipFwd, 1e-12)
    near('t=0 right knee is lifted', p0.rightLeg.lower, t.kneeLift, 1e-12)
    near('t=0 left arm is back', p0.leftArm.upper, t.armBack, 1e-12)
    near('t=0 right arm is forward', p0.rightArm.upper, -t.armFwd, 1e-12)
    // Half a cycle later the sides have swapped.
    eq('t=0.5 mirrors the legs', JSON.stringify(pHalf.rightLeg), JSON.stringify(p0.leftLeg))
    eq('t=0.5 mirrors the arms', JSON.stringify(pHalf.rightArm), JSON.stringify(p0.leftArm))
    // The passing position, mid-phase, has the legs crossing.
    const pQ = G.poseAt(t, 0.25)
    near('t=0.25 right hip halfway', pQ.rightLeg.upper, (t.hipBack - t.hipFwd) / 2, 1e-12)
    near('t=0.25 right knee is eased, not halfway', pQ.rightLeg.lower,
         t.kneeLift + (t.kneeExtend - t.kneeLift) * 0.5, 1e-12)
    near('t=0.25 is the top of the lift', pQ.lift, t.bounce, 1e-12)
    near('t=0 is the bottom of the lift', p0.lift, 0, 1e-12)
    near('t=0.5 is the bottom of the lift', pHalf.lift, 0, 1e-12)
    // Sway and rock alternate with the step; lean and head hold.
    near('hip yaw at t=0', p0.hip[1], t.sway, 1e-12)
    near('hip yaw at t=0.5', pHalf.hip[1], -t.sway, 1e-12)
    near('torso counters the hip', p0.torso[1], -t.sway / 2, 1e-12)
    near('roll at t=0', p0.torso[2], -t.rock, 1e-12)
    near('roll at t=0.5', pHalf.torso[2], t.rock, 1e-12)
    near('the trunk group carries no pitch', pQ.torso[0], 0, 1e-12)
    near('belly and chest add up to the lean', pQ.belly[0] + pQ.chest[0], t.lean, 1e-12)
    near('the hip gives back the belly bend', pQ.hip[0], t.hipLean, 1e-12)
    near('head holds', pQ.head[0], t.headPitch, 1e-12)
    near('elbow holds', pQ.rightArm.lower, -t.elbow, 1e-12)
    // The easing is Qt's InOutQuad.
    near('ease 0', G.easeInOutQuad(0), 0, 1e-12)
    near('ease 0.25', G.easeInOutQuad(0.25), 0.125, 1e-12)
    near('ease 0.5', G.easeInOutQuad(0.5), 0.5, 1e-12)
    near('ease 0.75', G.easeInOutQuad(0.75), 0.875, 1e-12)
    near('ease 1', G.easeInOutQuad(1), 1, 1e-12)
    near('t wraps', G.poseAt(t, 1.25).rightLeg.upper, pQ.rightLeg.upper, 1e-12)
}

section('a neutral pose is the legacy key pose')
{
    const p = G.poseAt(G.derive('walk', null), 0)
    eq('no lift', p.lift, 0)
    eq('level hip', JSON.stringify(p.hip), JSON.stringify([0, 0, 0]))
    eq('arms against the body', p.rightArm.out + p.leftArm.out, 0)
    eq('and not held out at all', p.rightArm.out, 0)
    eq('upright torso', JSON.stringify(p.torso), JSON.stringify([0, 0, 0]))
    eq('straight belly', JSON.stringify(p.belly), JSON.stringify([0, 0, 0]))
    eq('straight chest', JSON.stringify(p.chest), JSON.stringify([0, 0, 0]))
    eq('level head', JSON.stringify(p.head), JSON.stringify([0, 0, 0]))
}

// ------------------------------------------------------------------- the spine
section('the trunk is two segments: the lean is shared, the curve is differential')
{
    // Whatever the split does, the head must end up where the single-box
    // torso put it - the stride, the speed and every anchor above the waist
    // are derived from that.
    for (const f of [{ lean: 8 }, { lean: -6 }, { spineCurve: 20 }, { lean: 9, spineCurve: -14 }, {}]) {
        const t = G.derive('walk', G.compose([f]))
        near('walk ' + JSON.stringify(f) + ': belly + chest == lean',
             t.bellyLean + t.chestLean, t.lean, 1e-9)
        const r = G.derive('run', G.compose([f]))
        near('run ' + JSON.stringify(f) + ': belly + chest == lean',
             r.bellyLean + r.chestLean, r.lean, 1e-9)
    }

    const n = G.derive('walk', null)
    eq('a neutral walk has a straight back', n.bellyLean, 0)
    eq('a neutral walk has a straight chest', n.chestLean, 0)

    // spineCurve alone is a pure curve: the back rounds, the head does not move.
    const c = G.derive('walk', G.compose([{ spineCurve: 20 }]))
    near('a pure curve does not tilt the trunk', c.bellyLean + c.chestLean, 0, 1e-9)
    ok('a positive curve rounds the back forward', c.chestLean > 0 && c.bellyLean < 0)
    const a = G.derive('walk', G.compose([{ spineCurve: -20 }]))
    ok('a negative curve arches it and lifts the chest', a.chestLean < 0 && a.bellyLean > 0)

    // A factor lean bends over the spine rather than tipping as one piece:
    // even with no spineCurve asked for, the two segments differ.
    const l = G.derive('walk', G.compose([{ lean: 10 }]))
    ok('a factor lean curves on its own', l.chestLean - l.bellyLean > 4)
    // A base lean does not curve at all: a sprinter is a straight line from
    // the ankles, so the whole 12 degrees goes on the belly and the waist
    // joint stays shut.
    const run = G.derive('run', null)
    near('a neutral run tips rigidly', run.bellyLean, 12, 1e-9)
    near('a neutral run keeps the waist shut', run.chestLean, 0, 1e-9)
    near('a neutral run tips the legs with it', run.hipLean, 0, 1e-9)
}

section('the moods that need a back have one')
{
    const n = G.derive('walk', null)
    const back = (t) => t.chestLean - t.bellyLean   // how round the back is
    for (const [name, f] of [['dejected', G.presetFactors('dejected')],
                             ['elderly', G.presetFactors('elderly')],
                             ['sneak', G.presetFactors('sneak')],
                             ['soft build', G.BUILD_SOFT]]) {
        if (!f) continue
        ok(name + ' rounds the back', back(G.derive('walk', G.compose([f]))) > back(n) + 8)
    }
    for (const [name, f] of [['proud', G.presetFactors('proud')],
                             ['cheerful', G.presetFactors('cheerful')],
                             ['march', G.presetFactors('march')]]) {
        ok(name + ' arches it', back(G.derive('walk', G.compose([f]))) < back(n) - 4)
    }
    const toddler = G.derive('walk', G.compose([G.presetFactors('toddler')]))
    ok('a toddler stands belly-first', back(toddler) < 0 && toddler.lean < 0)
    const heavy = G.derive('walk', G.compose([G.presetFactors('heavy')]))
    ok('a heavy walker leans back over its weight', heavy.lean < 0)
}

section('the angry walk is short, hard steps with the arms held in')
{
    // The failure this pins: anger written as a BIGGER walk. It came out as a
    // lope with the forearms flapping, because ground covered easily is the
    // opposite of what anger looks like.
    const n = G.derive('walk', null)
    const angry = G.derive('walk', G.compose([G.emotionFactors('angry')]))
    ok('angry takes shorter steps than a neutral walk', angry.hipFwd < n.hipFwd)
    ok('angry takes them quicker', angry.cycleMs < n.cycleMs)
    ok('angry stamps', angry.kneeLift > n.kneeLift)
    // The fists ride in front of the hips because the elbow is bent, not
    // because the whole swing was slid forward - that produced two arms held
    // out in front that barely alternated.
    ok('angry bends the elbows', angry.elbow > 30)
    ok('angry still swings the upper arms past each other',
       angry.armFwd > 10 && angry.armBack > 4)
    ok('angry reaches less far back than a neutral walk', angry.armBack < n.armBack)
    ok('angry hunches the shoulders over the head',
       angry.chestLean - angry.bellyLean > 8)
    ok('angry shifts its weight side to side', angry.rock > n.rock)
    // ...but not much. Four degrees each way at this tempo is a waddle, and
    // rolling side to side is what WEIGHT looks like, not what anger does.
    ok('angry does not waddle', angry.rock <= G.derive('walk',
       G.compose([G.presetFactors('heavy')])).rock / 2)
    ok('angry carries the upper arms off the ribs', angry.armOut > 8)
}

process.exit(K.report('gait model'))
