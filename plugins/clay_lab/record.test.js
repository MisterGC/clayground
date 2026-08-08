// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/record.test.js
//
// The run record is the substrate a paper cites, so the properties asserted
// here are the ones that make citing safe: a record round-trips, it is
// byte-stable for the same run, it never repeats a reading through a dropout,
// and it stays committable however long the run was.

const K = require('../../labs/kits/kitcheck.js')
const R = K.load(__dirname, 'record.js',
    ['FORMAT', 'MAGIC', 'SAMPLES_MARKER', 'MAX_BYTES', 'SIG_DIGITS', 'num',
     'accInit', 'accAdd', 'accSummary', 'byteLength', 'serialize', 'parse',
     'build'])

// The run every case below is built from, unless it says otherwise: three
// sample ticks, two probes, and a gap where the second probe had no reading.
function sampleRun(extra) {
    return Object.assign({
        id: 'open-sky-42', lab: 'sensor-fusion-101', scenario: 'open-sky',
        seed: 42, steps: 180, stepSize: 1 / 60, sampleInterval: 0.05,
        command: 'labs/sensor-fusion-101/records/make.sh open-sky',
        params: [{ name: 'gpsSigma', value: 3, unit: 'm' },
                 { name: 'simSpeed', value: 0.5, unit: '' }],
        probes: [{ name: 'errFused', unit: 'm' }, { name: 'errGps', unit: 'm' }],
        rows: [[0, 0.1, 5.5], [0.05, 0.2, NaN], [0.1, 0.3, 4.5]]
    }, extra || {})
}

// --------------------------------------------------------------- the number

K.section('numbers')

K.eq('an exact value stays exact', R.num(1.5), '1.5')
K.eq('zero is zero, not 0.00000', R.num(0), '0')
K.eq('a long float is cut to six figures', R.num(0.7811234567890123), '0.781123')
K.eq('and rounds rather than truncates', R.num(0.78119999), '0.7812')
K.eq('a whole number keeps no decimal point', R.num(15.0), '15')
K.eq('a large value is not exponentialised needlessly', R.num(1234567), '1234570')
K.eq('a negative keeps its sign', R.num(-0.05), '-0.05')

// A cell is blank rather than "NaN": no measurement and a measurement of zero
// are different claims, and every consumer must be forced to tell them apart.
K.eq('NaN is an empty cell', R.num(NaN), '')
K.eq('Infinity is an empty cell', R.num(Infinity), '')
K.eq('null is an empty cell', R.num(null), '')

// --------------------------------------------------------- the accumulator

K.section('streaming statistics')

let acc = R.accInit()
for (const v of [2, 4, 4, 4, 5, 5, 7, 9]) R.accAdd(acc, v)
let s = R.accSummary(acc)
K.eq('count', s.count, 8)
K.near('mean', s.mean, 5, 1e-12)
K.near('population deviation', s.stddev, 2, 1e-12)
K.eq('first', s.first, 2)
K.eq('last', s.last, 9)
K.eq('min', s.min, 2)
K.eq('max', s.max, 9)

K.eq('an empty accumulator has no mean rather than a NaN',
     R.accSummary(R.accInit()).count, 0)
K.eq('and reports null, which serializes as JSON null',
     R.accSummary(R.accInit()).mean, null)

// A dropout must not enter the statistics at all - not as a zero, not as a
// repeat of the previous reading. This is the arithmetic half of the blank
// cell above.
acc = R.accInit()
for (const v of [1, NaN, 3]) R.accAdd(acc, v)
s = R.accSummary(acc)
K.eq('a dropout is not counted', s.count, 2)
K.near('and does not move the mean', s.mean, 2, 1e-12)

// Welford, for the same reason format.js uses it: a large baseline with tiny
// noise cancels catastrophically in the sum-of-squares form.
acc = R.accInit()
for (let i = 0; i < 1200; ++i) R.accAdd(acc, 1e6 + (i % 2 === 0 ? 1 : -1))
s = R.accSummary(acc)
K.near('a large offset keeps its mean', s.mean, 1e6, 1e-6)
K.near('and its deviation', s.stddev, 1, 1e-6)

// The streaming form must agree with the batch form in format.js, or a record
// and a live readout of the same run would disagree.
const F = K.load(__dirname, 'format.js', ['stats'])
const series = [0.31, 9.81, 9.79, 0.02, 4.5, 4.51, 0.9]
acc = R.accInit()
for (const v of series) R.accAdd(acc, v)
K.near('streaming mean equals the batch mean',
       R.accSummary(acc).mean, F.stats(series).mean, 1e-12)
K.near('streaming deviation equals the batch deviation',
       R.accSummary(acc).stddev, F.stats(series).stddev, 1e-12)

// ---------------------------------------------------------------- building

K.section('building a record')

const rec = R.build(sampleRun())
K.eq('columns are t plus the probes, in order', rec.columns.join(','),
     't,errFused,errGps')
K.eq('a summary per probe', rec.probes.length, 2)
K.eq('summaries keep the probe order', rec.probes[0].name, 'errFused')
K.eq('units travel with the summary', rec.probes[0].unit, 'm')
K.eq('a probe with a dropout counts only its readings',
     rec.probes[1].count, 2)
K.near('and summarises only them', rec.probes[1].mean, 5, 1e-12)
K.eq('the full probe counts every tick', rec.probes[0].count, 3)
K.near('duration is the last sample time', rec.duration, 0.1, 1e-12)

// ------------------------------------------------------------ round trip

K.section('round trip')

const text = R.serialize(rec)
K.ok('starts with the human line', text.startsWith(R.MAGIC))
K.ok('carries the samples marker', text.indexOf('\n' + R.SAMPLES_MARKER + '\n') > 0)
K.ok('ends with a newline', text.endsWith('\n'))

const back = R.parse(text)
K.eq('format survives', back.header.format, R.FORMAT)
K.eq('id survives', back.header.id, 'open-sky-42')
K.eq('lab survives', back.header.lab, 'sensor-fusion-101')
K.eq('scenario survives', back.header.scenario, 'open-sky')
K.eq('seed survives', back.header.seed, 42)
K.eq('steps survive', back.header.steps, 180)
K.eq('the regeneration command survives', back.header.command,
     'labs/sensor-fusion-101/records/make.sh open-sky')
K.eq('parameters survive, in order', back.header.params[0].name, 'gpsSigma')
K.eq('with their values', back.header.params[0].value, 3)
K.eq('and their units', back.header.params[0].unit, 'm')
K.eq('columns survive', back.columns.join(','), 't,errFused,errGps')
K.eq('every row survives', back.rows.length, 3)
K.near('a value survives', back.rows[0][1], 0.1, 1e-9)

K.eq('a dropout comes back as a gap, not a number',
     isFinite(back.rows[1][2]), false)
K.eq('and series() simply omits it', back.series('errGps').length, 2)
K.near('leaving the readings on their own sample times',
       back.series('errGps')[1].t, 0.1, 1e-12)
K.eq('probe() finds a summary by name', back.probe('errFused').name, 'errFused')
K.eq('and null for one that is not there', back.probe('nope'), null)

// The header block is valid JSON on its own - that is what lets any tool read
// a record's provenance without a parser for the table.
const headerText = text.split('\n' + R.SAMPLES_MARKER + '\n')[0]
                       .split('\n').filter(l => l[0] !== '#').join('\n')
K.ok('the header block parses as plain JSON', (() => {
    try { JSON.parse(headerText); return true } catch (e) { return false }
})())

K.throws('text that is not a record is refused, not guessed at',
         () => R.parse('hello\nworld\n'))
K.throws('and so is a future format version',
         () => R.parse(R.MAGIC + '\n{"format": "clay-lab-record/99"}\n'
                       + R.SAMPLES_MARKER + '\nt\n'))

// -------------------------------------------------------------- stability

K.section('byte stability')

K.eq('the same run serializes to the same bytes',
     R.serialize(R.build(sampleRun())), R.serialize(R.build(sampleRun())))
K.ok('and nothing in it looks like a wall clock',
     !/\b(19|20)\d\d-\d\d-\d\d\b/.test(text) && text.indexOf('"generated"') < 0)

// One changed parameter must be one changed LINE. That is the whole reason the
// JSON is emitted by hand instead of by JSON.stringify.
const changed = R.serialize(R.build(sampleRun({
    params: [{ name: 'gpsSigma', value: 9, unit: 'm' },
             { name: 'simSpeed', value: 0.5, unit: '' }]
})))
const a = text.split('\n'), b = changed.split('\n')
K.eq('a changed parameter changes exactly one line',
     a.filter((l, i) => l !== b[i]).length, 1)

// -------------------------------------------------------------- tripwire

K.section('the size tripwire')

function longRun(n) {
    const rows = []
    for (let i = 0; i < n; ++i) rows.push([i * 0.05, Math.sin(i) * 3.14159, i * 0.001])
    return R.build(sampleRun({ rows: rows }))
}

const big = longRun(20000)
const full = R.serialize(big, { maxBytes: 1e9 })
K.ok('a long run is genuinely over the limit when written in full',
     R.byteLength(full) > R.MAX_BYTES, R.byteLength(full))

const capped = R.serialize(big)
K.ok('but the written record stays under it',
     R.byteLength(capped) <= R.MAX_BYTES, R.byteLength(capped))

const cappedBack = R.parse(capped)
K.ok('by thinning the table', cappedBack.header.samples.stride > 1)
K.eq('which the record says out loud',
     cappedBack.header.samples.recorded, 20000)
K.ok('with a note a reader cannot miss',
     String(cappedBack.header.samples.note || '').indexOf('thinned') === 0)
K.eq('the kept rows are what the header claims',
     cappedBack.rows.length, cappedBack.header.samples.count)

// The point of thinning rather than truncating: the numbers a paper quotes are
// still over the WHOLE run, never over the sample that survived.
const fullBack = R.parse(full)
K.near('a summary is unchanged by thinning',
       cappedBack.probe('errFused').mean, fullBack.probe('errFused').mean, 1e-9)
K.eq('and still counts every sample', cappedBack.probe('errFused').count, 20000)

// A short run must not be touched at all - thinning is the exception, and a
// record that quietly dropped samples it had room for would be a lie.
K.eq('a short run keeps every sample', R.parse(R.serialize(rec)).header.samples.stride, 1)
K.eq('and says so', R.parse(R.serialize(rec)).header.samples.count, 3)

// ------------------------------------------------------------- byteLength

K.section('utf-8 length')

K.eq('ascii is one byte a character', R.byteLength('abc'), 3)
K.eq('a micro sign is two', R.byteLength('µ'), 2)
K.eq('an ohm sign is three', R.byteLength('Ω'), 3)
K.eq('an emoji surrogate pair is four', R.byteLength('📈'), 4)

// ----------------------------------------------------------------- degenerate

K.section('runs with nothing in them')

const empty = R.build({ id: 'empty', lab: 'x', scenario: 's', seed: 1,
                        probes: [], params: [], rows: [] })
const emptyText = R.serialize(empty)
const emptyBack = R.parse(emptyText)
K.eq('a run with no probes still produces a valid record',
     emptyBack.header.id, 'empty')
K.eq('with no samples', emptyBack.rows.length, 0)
K.eq('and empty lists rather than missing keys',
     emptyBack.header.probes.length, 0)

const silent = R.build(sampleRun({ rows: [[0, 1, NaN], [0.05, 2, NaN]] }))
K.eq('a probe that never read anything has a zero count',
     R.parse(R.serialize(silent)).probe('errGps').count, 0)
K.eq('and a null mean rather than a NaN',
     R.parse(R.serialize(silent)).probe('errGps').mean, null)

process.exit(K.report('lab record'))
