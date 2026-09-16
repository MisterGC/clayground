// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the martial-arts move set - the fourteen moves of the
// reference sheet (#238).
//
//     node plugins/clay_character3d/movesets/martialarts.test.js
//
// What it exists to pin is the set of claims a still cannot make. A
// screenshot shows a figure with its foot up; it cannot show that the foot
// came down again on the floor rather than a tenth of a leg into it, that the
// hand which is not punching stayed home, that the jab is the LEAD arm and the
// cross the REAR one, or that the knockdown ends on exactly the frame the
// get-up starts from - which is the whole reason those two are one movement
// and not two animations that nearly meet. It also pins what effort is
// allowed to be: the size of a move and its speed, never a different pose,
// and never anything at all on the two ground moves, where the floor is not
// negotiable.
const K = require('../../../labs/kits/kitcheck.js')

const M = K.load(__dirname, 'martialarts.js', [
    'STANCE', 'MOVES', 'MOVE_NAMES', 'moves', 'known', 'byName', 'restMove',
    'derive', 'poseAt', 'frameAt', 'ready', 'down', 'plant', 'settle',
    'mixFrame', 'mixPose', 'finish', 'arm', 'leg', 'over', 'look', 'shape', 'clamp'
])

const ok = K.ok, eq = K.eq, near = K.near, section = K.section
const rad = Math.PI / 180

// The engine applies eulerRotation as Z, then X, then Y, and the order is not
// a detail here: a limb is swung OUT on Z and pitched forward on X, so the
// swing out is also the ceiling on how high the pitch can carry it. Rotating
// in any other order would answer a different, higher foot for the roundhouse
// than the one the character actually shows.
function rot(v, e) {
  const cz = Math.cos(e[2] * rad), sz = Math.sin(e[2] * rad)
  let a = [v[0] * cz - v[1] * sz, v[0] * sz + v[1] * cz, v[2]]
  const cx = Math.cos(e[0] * rad), sx = Math.sin(e[0] * rad)
  a = [a[0], a[1] * cx - a[2] * sx, a[1] * sx + a[2] * cx]
  const cy = Math.cos(e[1] * rad), sy = Math.sin(e[1] * rad)
  return [a[0] * cy + a[2] * sy, a[1], -a[0] * sy + a[2] * cy]
}

// Where a limb's tip ends up, in limb lengths from the shoulder or the hip:
// +y up, +z forward, +x to the character's right. Two equal segments, which
// is the arm and is also Leg::upperRatio 0.5, followed from a rest direction
// of straight down through the lower joint and then the upper one.
function tip(j) {
  const d = [0, -1, 0]
  const u = rot(d, j.upper)
  const l = rot(rot(d, j.lower), j.upper)
  return [0.5 * u[0] + 0.5 * l[0], 0.5 * u[1] + 0.5 * l[1], 0.5 * u[2] + 0.5 * l[2]]
}

// The joint between the two segments, in the same frame.
function joint(j) {
  const u = rot([0, -1, 0], j.upper)
  return [0.5 * u[0], 0.5 * u[1], 0.5 * u[2]]
}

// How far above or below the floor the lower of the two feet is. A planted
// foot sits at -1.0: settle() puts the figure's lift at minus whatever the
// more extended of its two legs is shortened by, and the tip of that leg is
// exactly that much above the hip's own zero.
function floorGap(p) {
  return Math.min(p.lift + tip(p.rightLeg)[1], p.lift + tip(p.leftLeg)[1])
}

// The pose over the whole phase at which \a f is largest, and the phase it is
// at: a strike is judged at its peak and the peak is where the key holds.
function peak(T, f) {
  let best = -Infinity, at = 0
  for (let i = 0; i <= 400; i++) {
    const p = M.poseAt(T, i / 400)
    const v = f(p)
    if (v > best) { best = v; at = i / 400 }
  }
  return { value: best, t: at, pose: M.poseAt(T, at) }
}

// The largest difference between any two matching numbers in two poses.
function apart(p, q) {
  let worst = 0
  ;(function walk(a, b) {
    if (Array.isArray(a)) { a.forEach((v, i) => walk(v, b[i])); return }
    if (a !== null && typeof a === 'object') { for (const k in a) walk(a[k], b[k]); return }
    if (typeof a === 'number') worst = Math.max(worst, Math.abs(a - b))
  })(p, q)
  return worst
}

const AIRBORNE = ['jumpPunch', 'jumpKick']
const GROUND = ['knockdown', 'getUp']
const STANDING = M.MOVE_NAMES.filter(n => AIRBORNE.indexOf(n) < 0 && GROUND.indexOf(n) < 0)

// ---------------------------------------------------------------------- the set
section('the set is the fourteen moves of the sheet, in the order of the sheet')
{
  const sheet = ['stance', 'step', 'guard', 'jab', 'cross', 'uppercut', 'lowGuard',
                 'sweep', 'frontKick', 'roundhouse', 'jumpPunch', 'jumpKick',
                 'knockdown', 'getUp']
  eq('all fourteen are there, by name and in order',
     M.MOVE_NAMES.join(','), sheet.join(','))
  const list = M.moves()
  eq('and moves() answers one entry per move', list.length, M.MOVE_NAMES.length)
  eq('in the same order', list.map(m => m.name).join(','), M.MOVE_NAMES.join(','))
  ok('each carrying a name, a label, a group, whether it loops and whether it holds',
     list.every(m => typeof m.name === 'string' && m.label.length > 0
                  && typeof m.group === 'string'
                  && typeof m.loop === 'boolean' && typeof m.holds === 'boolean'))
  eq('the groups are the sheet\'s five',
     [...new Set(list.map(m => m.group))].join(','),
     'standing,crouched,kicks,airborne,ground')
  ok('the knockdown is the one move that holds where it ends',
     list.filter(m => m.holds).map(m => m.name).join(',') === 'knockdown')
  ok('it knows a move it has', M.known('jab') && M.byName('jab') !== null)
  ok('and does not know one it has not', !M.known('juggle') && M.byName('juggle') === null)
  eq('an unknown move falls back to the stance rather than throwing',
     M.derive('juggle').move, 'stance')
  eq('and the stance is what the figure rests in', M.restMove(), 'stance')
}

// -------------------------------------------------------------------- chaining
section('every move starts and ends somewhere the next one can pick up from')
{
  // This is what makes a one-shot hand back and a loop loop: the first and
  // last key of every move are the same ready stance, so the pose either end
  // of it is the same pose and no two moves can be chained into a jump.
  for (const n of M.MOVE_NAMES) {
    if (GROUND.indexOf(n) >= 0) continue
    const T = M.derive(n)
    eq(n + ' ends where it began',
       JSON.stringify(M.poseAt(T, 1)), JSON.stringify(M.poseAt(T, 0)))
  }
  eq('the knockdown ends on the down frame and the get-up starts on that same frame',
     JSON.stringify(M.poseAt(M.derive('getUp'), 0)),
     JSON.stringify(M.poseAt(M.derive('knockdown'), 1)))
  eq('and the get-up ends standing in the ready stance',
     JSON.stringify(M.poseAt(M.derive('getUp'), 1)),
     JSON.stringify(M.poseAt(M.derive('stance'), 0)))
}

section('a one-shot does not wrap and a loop does')
{
  const loop = M.derive('stance'), shot = M.derive('knockdown')
  ok('the stance is a loop and the knockdown is not', loop.loop && !shot.loop)
  eq('a loop read past its end is read from its start again',
     JSON.stringify(M.poseAt(loop, 1.25)), JSON.stringify(M.poseAt(loop, 0.25)))
  eq('and read before its start from its end',
     JSON.stringify(M.poseAt(loop, -0.75)), JSON.stringify(M.poseAt(loop, 0.25)))
  eq('a one-shot read past its end stays on its last frame',
     JSON.stringify(M.poseAt(shot, 1.5)), JSON.stringify(M.poseAt(shot, 1)))
  eq('and read before its start stays on its first',
     JSON.stringify(M.poseAt(shot, -0.5)), JSON.stringify(M.poseAt(shot, 0)))
  // The knockdown has to STAY on the floor: a one-shot that wrapped would put
  // a knocked-down figure back on its feet by itself.
  ok('so the knockdown is still on the floor long after it landed',
     M.poseAt(shot, 4).lift === M.poseAt(shot, 1).lift)
}

// ---------------------------------------------------------------------- the floor
section('the figure stands on the floor and does not stand in it')
{
  for (const n of STANDING) {
    const T = M.derive(n)
    let lo = Infinity, hi = -Infinity
    for (let i = 0; i <= 400; i++) {
      const g = floorGap(M.poseAt(T, i / 400))
      lo = Math.min(lo, g); hi = Math.max(hi, g)
    }
    ok(n + ' keeps its lower foot on the floor throughout',
       lo > -1.07 && hi < -0.93, 'lowest ' + lo.toFixed(4) + ', highest ' + hi.toFixed(4))
  }
  for (const n of AIRBORNE) {
    const T = M.derive(n)
    let lo = Infinity, hi = -Infinity
    for (let i = 0; i <= 400; i++) {
      const g = floorGap(M.poseAt(T, i / 400))
      lo = Math.min(lo, g); hi = Math.max(hi, g)
    }
    ok(n + ' leaves the floor', hi > -0.5, 'highest ' + hi.toFixed(4))
    ok('and lands on it again', lo <= -1.0, 'lowest ' + lo.toFixed(4))
  }
}

// -------------------------------------------------------------------- the strikes
section('a jab is the lead hand and a cross is the rear')
{
  const jab = peak(M.derive('jab'), p => tip(p.leftArm)[2])
  const cross = peak(M.derive('cross'), p => tip(p.rightArm)[2])
  ok('the jab puts the left hand out at reach',
     jab.value > 0.9, 'reached ' + jab.value.toFixed(4))
  ok('and the right hand stays home', tip(jab.pose.rightArm)[2] < 0.6,
     'right at ' + tip(jab.pose.rightArm)[2].toFixed(4))
  ok('the cross puts the right hand out at reach',
     cross.value > 0.9, 'reached ' + cross.value.toFixed(4))
  ok('and the left hand stays home', tip(cross.pose.leftArm)[2] < 0.6,
     'left at ' + tip(cross.pose.leftArm)[2].toFixed(4))
  ok('the cross is the longer move of the two',
     M.derive('cross').cycleMs > M.derive('jab').cycleMs)
  // The cross is the trunk, not the arm: the hips turn THROUGH the blade,
  // where a jab only turns further into it.
  ok('the cross turns the trunk through the stance\'s blade',
     jab.pose.torso[1] > M.STANCE.blade && cross.pose.torso[1] < M.STANCE.blade,
     'jab ' + jab.pose.torso[1].toFixed(2) + ', stance ' + M.STANCE.blade
     + ', cross ' + cross.pose.torso[1].toFixed(2))
}

section('an uppercut rises and a guard covers')
{
  const up = peak(M.derive('uppercut'), p => tip(p.rightArm)[1])
  ok('the rear fist finishes above the shoulder',
     up.value > 0.35, 'fist at ' + up.value.toFixed(4))
  // What separates a rising punch from an overhead swing: the elbow does not
  // go up with the fist.
  ok('and the elbow does not go up with it',
     joint(up.pose.rightArm)[1] <= 0,
     'elbow at ' + joint(up.pose.rightArm)[1].toFixed(4))

  const cover = M.poseAt(M.derive('guard'), 0.5)
  for (const [name, a] of [['the rear', cover.rightArm], ['the lead', cover.leftArm]]) {
    ok(name + ' fist comes up above its own elbow', tip(a)[1] > joint(a)[1])
    ok('and ' + name + ' fist comes up past the shoulder line', tip(a)[1] > 0,
       'fist at ' + tip(a)[1].toFixed(4))
  }
}

// ----------------------------------------------------------------------- the kicks
section('the kicks go where their names say and chamber before they go')
{
  const front = peak(M.derive('frontKick'), p => tip(p.rightLeg)[1])
  const round = peak(M.derive('roundhouse'), p => tip(p.rightLeg)[1])
  ok('the front kick puts the right foot above the hip',
     front.value > 0.2, 'foot at ' + front.value.toFixed(4))
  ok('and well forward of it', tip(front.pose.rightLeg)[2] > 0.7,
     'forward ' + tip(front.pose.rightLeg)[2].toFixed(4))
  ok('the roundhouse gets the same foot higher still', round.value > front.value,
     'round ' + round.value.toFixed(4) + ' vs front ' + front.value.toFixed(4))

  function sideways(T) {
    let out = 0
    for (let i = 0; i <= 400; i++)
      out = Math.max(out, Math.abs(tip(M.poseAt(T, i / 400).rightLeg)[0]))
    return out
  }
  const roundX = sideways(M.derive('roundhouse')), frontX = sideways(M.derive('frontKick'))
  ok('and takes it further out to the side', roundX > frontX,
     'round ' + roundX.toFixed(4) + ' vs front ' + frontX.toFixed(4))

  // A leg that goes out straight from the stance is a swing; the knee that
  // came up first is the whole difference.
  for (const [n, chamberT, outT] of [['the front kick', 0.24, 0.48],
                                     ['the roundhouse', 0.26, 0.54]]) {
    const T = M.derive(n === 'the front kick' ? 'frontKick' : 'roundhouse')
    const folded = M.poseAt(T, chamberT).rightLeg.lower[0]
    const straight = M.poseAt(T, outT).rightLeg.lower[0]
    ok(n + ' chambers the knee before it extends', folded > straight * 4,
       'chamber ' + folded.toFixed(1) + ', extension ' + straight.toFixed(1))
  }
}

section('the sweep stays low and goes down onto a hand')
{
  const T = M.derive('sweep')
  let high = -Infinity, out = 0
  for (let i = 0; i <= 400; i++) {
    const v = tip(M.poseAt(T, i / 400).rightLeg)
    high = Math.max(high, v[1]); out = Math.max(out, Math.abs(v[0]))
  }
  ok('the sweeping foot never comes up to the hip', high < 0,
     'highest ' + high.toFixed(4))
  ok('and goes a long way out to the side', out > 0.6, 'out ' + out.toFixed(4))
  // The planted hand IS the move: without it the figure is squatting and
  // waving a leg.
  eq('the hand opens to plant through the middle of it', M.poseAt(T, 0.5).hand, 'open')
  eq('and is a fist at the start', M.poseAt(T, 0).hand, 'fist')
  eq('and a fist again at the end', M.poseAt(T, 1).hand, 'fist')
}

// -------------------------------------------------------------------------- effort
section('effort is size and speed, never a different pose')
{
  for (const n of M.MOVE_NAMES) {
    const calm = M.derive(n, { intensity: 0 }).cycleMs
    const hard = M.derive(n, { intensity: 1 }).cycleMs
    ok('a harder ' + n + ' is a faster one', hard < calm,
       'hard ' + hard + ', calm ' + calm)
    ok('and still not a flicker', hard >= 180, 'hard ' + hard)
  }
  const light = peak(M.derive('jab', { intensity: 0 }), p => tip(p.leftArm)[2])
  const hard = peak(M.derive('jab', { intensity: 1 }), p => tip(p.leftArm)[2])
  ok('a hard jab reaches further than a light one', hard.value > light.value,
     'hard ' + hard.value.toFixed(4) + ', light ' + light.value.toFixed(4))
  ok('and a light one still reaches forward', light.value > 0.8,
     'light ' + light.value.toFixed(4))
  for (const n of ['jab', 'roundhouse']) {
    eq('intensity is clamped on the ' + n, M.derive(n, { intensity: 9 }).cycleMs,
       M.derive(n, { intensity: 1 }).cycleMs)
  }
  // A knockdown scaled up misses the floor and one scaled down does not
  // reach it, so effort is kept off the two ground moves entirely.
  for (const n of GROUND) {
    eq('effort does not touch the ' + n,
       JSON.stringify(M.derive(n, { intensity: 0 }).keys),
       JSON.stringify(M.derive(n, { intensity: 1 }).keys))
  }
}

// ---------------------------------------------------------------------- the fall
section('the fall lands on the floor of this figure')
{
  const tall = M.derive('knockdown',
    { legHeight: 4, hipHeight: 1.6, footHeight: 0.5, torsoDepth: 1.25 }).downLift
  const short = M.derive('knockdown',
    { legHeight: 4, hipHeight: 0.9, footHeight: 0.5, torsoDepth: 1.25 }).downLift
  ok('a figure whose waist stands higher is dropped further', tall < short,
     'tall ' + tall.toFixed(4) + ', short ' + short.toFixed(4))
  near('and with no body given it is the default figure\'s',
       M.derive('knockdown').downLift, -1.18, 1e-9)
  const p = M.poseAt(M.derive('knockdown'), 1)
  ok('the down frame pitches the whole trunk onto its back', p.torso[0] < -60,
     'torso ' + p.torso[0].toFixed(1))
  eq('and opens the hands', p.hand, 'open')
  eq('and the fall drops the figure by exactly that much', p.lift, M.derive('knockdown').downLift)
}

// --------------------------------------------------------------------- the edges
section('the mixers read numbers between and switch names at the halfway point')
{
  const a = { angle: 0, lift: -1, hand: 'fist' }
  const b = { angle: 10, lift: 0, hand: 'open' }
  near('a number a quarter of the way is a quarter of the way',
       M.mixFrame(a, b, 0.25).angle, 2.5, 1e-12)
  eq('a name is the first one before the halfway point', M.mixFrame(a, b, 0.49).hand, 'fist')
  eq('and the second one at it', M.mixFrame(a, b, 0.5).hand, 'open')
  near('and the numbers keep reading between either way',
       M.mixFrame(a, b, 0.5).lift, -0.5, 1e-12)

  const stand = M.poseAt(M.derive('stance'), 0)
  const punch = M.poseAt(M.derive('cross'), 0.46)
  eq('a pose mixed nowhere is the pose it started at',
     JSON.stringify(M.mixPose(stand, punch, 0)), JSON.stringify(stand))
  // Not JSON-identical at the far end: p + (q - p) is q only to within
  // floating point, and it comes out about 5e-15 off on one wrist angle.
  ok('and a pose mixed all the way is the pose it was going to',
     apart(M.mixPose(stand, punch, 1), punch) < 1e-12
     && M.mixPose(stand, punch, 1).hand === punch.hand,
     'off by ' + apart(M.mixPose(stand, punch, 1), punch))
  const half = M.mixPose(stand, punch, 0.5)
  near('and half way it is half way in lift', half.lift, (stand.lift + punch.lift) / 2, 1e-12)
  near('and half way in drift', half.drift, (stand.drift + punch.drift) / 2, 1e-12)
}

section('a bent leg is a shorter leg')
{
  eq('a straight leg carried straight down takes nothing off the height',
     M.plant(0, 0, 0), 0)
  ok('a folded knee takes some off', M.plant(0, 30, 0) > 0)
  ok('and a further folded one takes more', M.plant(0, 60, 0) > M.plant(0, 30, 0))
  // The leg is also carried out to the side, and the sheet's stances are wide
  // enough that ignoring that puts a deep crouch into the ground.
  ok('and a leg carried out to the side takes more off than one hanging under the hip',
     M.plant(0, 60, 30) > M.plant(0, 60, 0))
}

section('every pose carries what an animator has to write')
{
  for (const n of M.MOVE_NAMES) {
    const p = M.poseAt(M.derive(n), 0.37)
    ok(n + ' answers with a lift, a drift and a hand',
       typeof p.lift === 'number' && typeof p.drift === 'number'
       && (p.hand === 'fist' || p.hand === 'open'))
  }
  const T = M.derive('cross')
  eq('poseAt is frameAt finished', JSON.stringify(M.poseAt(T, 0.3)),
     JSON.stringify(M.finish(M.frameAt(T, 0.3))))
  eq('the shape curves start where they start', M.shape('out', 0), 0)
  eq('and end where they end', M.shape('out', 1), 1)
  eq('a hold is nothing until it is everything', M.shape('hold', 0.99), 0)
  eq('clamp holds the ends', M.clamp(9, 0, 1), 1)
}

process.exit(K.report('martial arts move set'))
