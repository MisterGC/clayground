// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/scale.test.js
//
// The instrument model, checked the way palette.test.js and tokens.test.js
// check theirs: against the rules that make a scale a scale, not against the
// numbers a particular meter happens to print.
//
// It earns a suite because every face in the kernel reads through it. A wrong
// log mapping, an off-by-one range selection or a peak marker that never falls
// is a bug in four components at once, and none of them would say so - a
// needle at 40% looks exactly as convincing as a needle at 60%.

const K = require('../../labs/kits/kitcheck.js')
const S = K.load(__dirname, 'scale.js',
    ['LOG_DECADES', 'SEVERITIES', 'pickRange', 'logFloor', 'fractionOf',
     'valueAt', 'niceNum', 'niceStep', 'ticksFor', 'logTicks', 'tickDigits',
     'zonesFrom', 'severityAt', 'lowPass', 'peakStep'])

// ------------------------------------------------------------- self-ranging

K.section('self-ranging')

const RANGES = [0.01, 0.1, 1, 10]

K.eq('picks the smallest range that holds the reading', S.pickRange(0.05, RANGES), 0.1)
K.eq('a reading exactly at a range stays on it', S.pickRange(0.1, RANGES), 0.1)
K.eq('zero takes the finest range', S.pickRange(0, RANGES), 0.01)
K.eq('the sign does not choose the range', S.pickRange(-0.05, RANGES), 0.1)
K.eq('past the top range the meter pins rather than inventing one',
     S.pickRange(500, RANGES), 10)
K.eq('a single range is a fixed-range meter', S.pickRange(7, [2]), 2)
K.eq('ranges given out of order still select correctly',
     S.pickRange(0.05, [10, 0.01, 1, 0.1]), 0.1)
K.eq('no ranges at all is not a range', S.pickRange(1, []), 0)
K.eq('a nonsense reading falls to the finest range', S.pickRange(NaN, RANGES), 0.01)

// --------------------------------------------------------- position mapping

K.section('linear mapping')

K.near('the bottom limit is 0', S.fractionOf(0, 0, 2), 0)
K.near('the top limit is 1', S.fractionOf(2, 0, 2), 1)
K.near('the middle is a half', S.fractionOf(1, 0, 2), 0.5)
K.near('a scale that does not start at zero still maps its middle',
       S.fractionOf(-21, -48, 6), 0.5)
K.near('below the scale pins at 0', S.fractionOf(-5, 0, 2), 0)
K.near('above the scale pins at 1', S.fractionOf(99, 0, 2), 1)
K.near('a collapsed scale does not divide by zero', S.fractionOf(1, 3, 3), 0)
K.near('a nonsense reading sits at the bottom', S.fractionOf(NaN, 0, 2), 0)

// The pair has to be an actual inverse, or a face that puts a tick at
// fractionOf(v) and labels it valueAt(f) contradicts itself.
for (const f of [0, 0.13, 0.5, 0.77, 1]) {
    K.near('linear round-trip at ' + f,
           S.fractionOf(S.valueAt(f, -48, 6), -48, 6), f, 1e-9)
}

K.section('log mapping')

// A decade is a decade: with four decades on the scale each one takes a
// quarter of it, whatever the numbers are.
K.near('the top decade takes the top quarter of four decades',
       S.fractionOf(1, 1e-4, 1, true), 1)
K.near('one decade down is three quarters along',
       S.fractionOf(0.1, 1e-4, 1, true), 0.75, 1e-9)
K.near('two decades down is halfway', S.fractionOf(0.01, 1e-4, 1, true), 0.5, 1e-9)

K.near('min 0 on a log scale means LOG_DECADES below the top',
       S.logFloor(0, 1), Math.pow(10, -S.LOG_DECADES))
K.near('a log scale with min 0 still maps its top decade',
       S.fractionOf(1, 0, 1, true), 1)
K.near('anything at or under the floor pins at the bottom',
       S.fractionOf(1e-9, 0, 1, true), 0)

// The property that makes a log scale worth having: equal RATIOS take equal
// space, which is what a level meter is for.
const spanA = S.fractionOf(0.02, 1e-3, 1, true) - S.fractionOf(0.01, 1e-3, 1, true)
const spanB = S.fractionOf(0.2, 1e-3, 1, true) - S.fractionOf(0.1, 1e-3, 1, true)
K.near('a doubling takes the same room anywhere on a log scale', spanA, spanB, 1e-9)

for (const f of [0, 0.2, 0.5, 1]) {
    K.near('log round-trip at ' + f,
           S.fractionOf(S.valueAt(f, 1e-3, 1, true), 1e-3, 1, true), f, 1e-9)
}

K.ok('the log mapping rises', S.fractionOf(0.5, 1e-3, 1, true)
                              > S.fractionOf(0.05, 1e-3, 1, true))

// ---------------------------------------------------------------- nice ticks

K.section('nice numbers')

K.eq('a nice number is 1, 2, 5 or a decade of them', S.niceNum(0.4, true), 0.5)
K.eq('and again a decade up', S.niceNum(40, true), 50)
K.eq('rounding down where it should', S.niceNum(1.2, true), 1)
K.eq('zero has no nice number', S.niceNum(0, true), 0)

for (const [lo, hi] of [[0, 1], [0, 2], [0, 10], [-48, 6], [0, 30], [0, 0.05]]) {
    const step = S.niceStep(lo, hi, 6)
    const m = step / Math.pow(10, Math.floor(Math.log10(step)))
    K.ok('the step for ' + lo + '..' + hi + ' is a 1/2/5 decade',
         [1, 2, 5, 10].some(x => Math.abs(m - x) < 1e-9), 'step ' + step)
}

K.section('ticks on a scale')

const t02 = S.ticksFor(0, 2, 6)
K.ok('ticks never leave the instrument\'s limits',
     t02.every(t => t.value >= -1e-9 && t.value <= 2 + 1e-9),
     t02.map(t => t.value).join(' '))
K.ok('the majors on 0..2 are the half volts',
     t02.filter(t => t.major).map(t => t.value).join(' ') === '0 0.5 1 1.5 2',
     t02.filter(t => t.major).map(t => t.value).join(' '))
K.ok('there are minors between the majors', t02.some(t => !t.major))
K.ok('a bar gets a usable number of gradations, never a comb',
     t02.length >= 5 && t02.length <= 40, t02.length)

for (const [lo, hi] of [[0, 1], [0, 2], [0, 10], [-48, 6], [0, 30],
                        [0, 0.05], [0, 1e6], [-1, 1]]) {
    const ts = S.ticksFor(lo, hi, 6)
    let rising = true
    for (let i = 1; i < ts.length; ++i)
        if (ts[i].value <= ts[i - 1].value) rising = false
    K.ok('ticks rise and stay inside ' + lo + '..' + hi,
         rising && ts.length > 1
         && ts[0].value >= Math.min(lo, hi) - 1e-9
         && ts[ts.length - 1].value <= Math.max(lo, hi) + 1e-9,
         ts.map(t => t.value).join(' '))
    K.ok('and some of them are labelled majors on ' + lo + '..' + hi,
         ts.some(t => t.major))
}

K.ok('a collapsed scale produces no ticks rather than looping',
     S.ticksFor(3, 3, 6).length === 0)

const tl = S.ticksFor(1e-3, 1, 6, true)
K.ok('a log scale ticks by decade',
     tl.filter(t => t.major).map(t => t.value.toExponential(0)).join(' ')
     === '1e-3 1e-2 1e-1 1e+0',
     tl.filter(t => t.major).map(t => t.value).join(' '))
K.ok('a short log scale fills in the 1-2-5 rungs',
     S.ticksFor(0.1, 1, 6, true).some(t => !t.major))

K.section('gradation labels')

K.eq('whole-number steps carry no decimals', S.tickDigits(10), 0)
K.eq('a half-unit step carries one', S.tickDigits(0.5), 1)
K.eq('a hundredth step carries two', S.tickDigits(0.05), 2)
K.eq('a step of exactly one carries none', S.tickDigits(1), 0)
K.eq('a nonsense step is not a crash', S.tickDigits(0), 0)

// Every gradation on one scale has to be labelled to the SAME precision, or
// the instrument prints two different scales on one face.
for (const [lo, hi] of [[0, 2], [-48, 6], [0, 30], [0, 0.05]]) {
    const d = S.tickDigits(S.niceStep(lo, hi, 6))
    const labels = S.ticksFor(lo, hi, 6).filter(t => t.major)
                    .map(t => t.value.toFixed(d))
    K.ok('the labels of ' + lo + '..' + hi + ' resolve their own step',
         new Set(labels).size === labels.length, labels.join(' '))
}

// ---------------------------------------------------------------- severities

K.section('zones')

const Z = S.zonesFrom(0.6, 0.85, 0, 1)
K.eq('a good reading is ok', S.severityAt(0.2, Z), 'ok')
K.eq('past the ok bound it warns', S.severityAt(0.7, Z), 'warn')
K.eq('past the warn bound it alarms', S.severityAt(0.95, Z), 'alarm')
K.eq('a boundary belongs to the calmer band', S.severityAt(0.6, Z), 'warn')
K.eq('full scale still has a severity', S.severityAt(1, Z), 'alarm')
K.eq('no zones means the instrument has no opinion', S.severityAt(0.99, []), 'ok')

// The bug this pair exists for: a needle pinned PAST full scale on an
// instrument banded red at the top read back "ok", because a value off the end
// of the scale is in no band at all. Every face pins the reading at the limit,
// so the severity has to pin with it.
K.eq('a reading past the top takes the top band', S.severityAt(2.4, Z), 'alarm')
K.eq('a reading under the bottom takes the bottom band',
     S.severityAt(-3, Z), 'ok')
K.eq('and on a scale whose bad band is at the BOTTOM',
     S.severityAt(-99, S.zonesFrom(-40, -20, -60, 0)), 'ok')
K.eq('an undeclared zone list is not a crash', S.severityAt(0.5, undefined), 'ok')

K.ok('an ok bound alone still alarms above it',
     S.severityAt(0.9, S.zonesFrom(0.6, NaN, 0, 1)) === 'alarm')
K.ok('the zones cover the scale end to end', (() => {
    const z = S.zonesFrom(0.6, 0.85, 0, 1)
    return z[0].from === 0 && z[z.length - 1].to === 1
})())
K.ok('severities are ordered worst-last', S.SEVERITIES.join(' ') === 'ok warn alarm')

// A scale that runs the other way (a depth, a countdown) must not silently
// classify everything as ok.
K.eq('a descending band still catches its reading',
     S.severityAt(5, [{ from: 10, to: 0, severity: 'alarm' }]), 'alarm')

// --------------------------------------------------------------- dynamics

K.section('the movement')

K.eq('no damping is no lag', S.lowPass(0, 10, 0, 1 / 60), 10)
K.ok('a damped movement approaches without overshooting', (() => {
    let v = 0
    for (let i = 0; i < 400; ++i) {
        v = S.lowPass(v, 10, 0.3, 1 / 60)
        if (v > 10 + 1e-9 || v < 0) return false
    }
    return Math.abs(v - 10) < 1e-3
})())

K.near('one time constant closes about 63% of the gap',
       S.lowPass(0, 1, 0.5, 0.5), 0.632, 1e-3)

// Frame-rate independence: the same sim time must give the same needle,
// whether it arrived in 60 steps or in 6.
const fine = (() => { let v = 0; for (let i = 0; i < 60; ++i) v = S.lowPass(v, 1, 0.4, 1 / 60); return v })()
const coarse = (() => { let v = 0; for (let i = 0; i < 6; ++i) v = S.lowPass(v, 1, 0.4, 1 / 6); return v })()
K.near('the lag is frame-rate independent', fine, coarse, 2e-3)

K.section('peak hold')

K.eq('a new maximum is taken at once',
     S.peakStep(0.2, 5, 0.9, 1 / 30, 1, 0.3).peak, 0.9)
K.eq('and resets the hold clock',
     S.peakStep(0.2, 5, 0.9, 1 / 30, 1, 0.3).age, 0)

let st = { peak: 0.9, age: 0 }
for (let i = 0; i < 20; ++i) st = S.peakStep(st.peak, st.age, 0.1, 1 / 30, 1.0, 0.3)
K.near('the marker holds while the hold time runs', st.peak, 0.9, 1e-9)

for (let i = 0; i < 60; ++i) st = S.peakStep(st.peak, st.age, 0.1, 1 / 30, 1.0, 0.3)
K.ok('then it falls', st.peak < 0.9 && st.peak > 0.1, st.peak)

for (let i = 0; i < 600; ++i) st = S.peakStep(st.peak, st.age, 0.1, 1 / 30, 1.0, 0.3)
K.near('and comes to rest on the live reading, never under it', st.peak, 0.1, 1e-9)

K.ok('the marker never leaves the scale', (() => {
    let s = { peak: 0, age: 0 }
    for (let i = 0; i < 500; ++i) {
        s = S.peakStep(s.peak, s.age, Math.sin(i) * 2, 1 / 30, 0.5, 0.4)
        if (s.peak < 0 || s.peak > 1) return false
    }
    return true
})())

K.ok('a zero fall rate is a hold that never releases', (() => {
    let s = { peak: 0.8, age: 0 }
    for (let i = 0; i < 300; ++i) s = S.peakStep(s.peak, s.age, 0.1, 1 / 30, 0.2, 0)
    return Math.abs(s.peak - 0.8) < 1e-9
})())

process.exit(K.report('lab instrument scale'))
