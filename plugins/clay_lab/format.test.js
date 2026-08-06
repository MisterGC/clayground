// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/format.test.js
//
// The quantity layer. Three labs hand-rolled this rule and each got a
// different set of edges right; the cases below are the union of what those
// three implementations had to learn, so the fourth caller inherits all of it.

const K = require('../../labs/kits/kitcheck.js')
const F = K.load(__dirname, 'format.js',
    ['PREFIXES', 'PREFIXABLE', 'takesPrefix', 'autoDigits', 'prefixFor',
     'parts', 'qty', 'stats'])

// ------------------------------------------------------------- the crossover

K.section('SI prefixes')

K.eq('a small current becomes milliamps', F.qty(0.05, 'A', 1), '50.0 mA')
K.eq('a whole amp stays an amp', F.qty(1.5, 'A', 2), '1.50 A')
K.eq('a large resistance becomes kilo-ohms', F.qty(1500, 'Ω', 2), '1.50 kΩ')
K.eq('and a very large one mega', F.qty(2.2e6, 'Ω', 1), '2.2 MΩ')
K.eq('a short time becomes milliseconds', F.qty(0.004, 's', 1), '4.0 ms')
K.eq('microamps exist too', F.qty(3e-6, 'A', 1), '3.0 µA')

// The boundary electronics had to special-case by hand: at two digits 0.9996 A
// rounds to 1.00, and printing "999.60 mA" beside a needle already at the end
// of its scale is the bug that rule existed to avoid.
K.eq('a value that rounds up to 1 takes the larger prefix',
     F.qty(0.9996, 'A', 2), '1.00 A')
K.eq('a value that does not stays below it',
     F.qty(0.94, 'A', 2), '940.00 mA')

K.eq('zero has no prefix', F.qty(0, 'A', 2), '0.00 A')
K.eq('a negative keeps its sign and gets the same prefix as its magnitude',
     F.qty(-0.05, 'A', 1), '-50.0 mA')

// --------------------------------------------------------- units that cannot

K.section('units that take no prefix')

K.ok('a rate is not prefixable', !F.takesPrefix('/min'))
K.ok('a percentage is not prefixable', !F.takesPrefix('%'))
K.ok('a bare count is not prefixable', !F.takesPrefix(''))
K.ok('amps are', F.takesPrefix('A'))

K.eq('a rate is printed as it stands', F.qty(1500, '/min', 0), '1500 /min')
K.eq('a percentage is printed as it stands', F.qty(0.004, '%', 3), '0.004 %')
K.eq('a unitless value is just a number', F.qty(12.345, '', 2), '12.35')

// --------------------------------------------------------------- the digits

K.section('significant figures')

K.eq('under ten gets two decimals', F.autoDigits(4.2), 2)
K.eq('under a hundred gets one', F.autoDigits(42), 1)
K.eq('above gets none', F.autoDigits(420), 0)

K.ok('without digits every reading is about three figures wide',
     ['0.05', '1.5', '15', '150'].every(v => {
         const s = F.qty(Number(v), 'A')
         const digits = s.split(' ')[0].replace('-', '').replace(/^\d+\.?/, '').length
         return digits <= 2
     }))

// A rounding artefact is never a reading: -0.004 at two digits is zero, and
// "-0.00" on a dial reads as a fault that is not there.
K.eq('minus zero is zero', F.qty(-0.0004, '', 2), '0.00')

// ------------------------------------------------------------ the separator

K.section('the decimal separator')

K.eq('German gets a comma', F.qty(0.05, 'A', 1, ','), '50,0 mA')
K.eq('English keeps the point', F.qty(0.05, 'A', 1, '.'), '50.0 mA')
K.eq('the separator does not touch the prefix',
     F.parts(1500, 'Ω', 2, ',').fullUnit, 'kΩ')

// ---------------------------------------------------------------- the parts

K.section('parts')

const p = F.parts(0.05, 'A', 1, '.')
K.eq('number is the scaled magnitude', p.number, '50.0')
K.eq('prefix is separate', p.prefix, 'm')
K.eq('unit is untouched', p.unit, 'A')
K.eq('fullUnit is what goes beside the number', p.fullUnit, 'mA')
K.eq('qty is parts, joined', F.qty(0.05, 'A', 1, '.'), p.number + ' ' + p.fullUnit)

// ------------------------------------------------------------------- stats

K.section('mean and deviation')

const st = F.stats([2, 4, 4, 4, 5, 5, 7, 9])
K.near('mean', st.mean, 5, 1e-12)
K.near('population deviation', st.stddev, 2, 1e-12)
K.eq('count', st.count, 8)

K.eq('an empty series has no mean rather than a NaN', F.stats([]).count, 0)
K.near('a constant series has zero deviation', F.stats([3, 3, 3, 3]).stddev, 0, 1e-12)
K.ok('non-finite samples are skipped rather than poisoning the mean',
     isFinite(F.stats([1, NaN, 3, Infinity]).mean))

// The reason this is Welford's and not sum-of-squares: a probe's full 1200
// samples of a large baseline with small noise. The naive form subtracts two
// nearly equal large numbers and can return a negative variance.
const big = []
for (let i = 0; i < 1200; ++i) big.push(1e6 + (i % 2 === 0 ? 1 : -1))
const bs = F.stats(big)
K.near('a large offset with tiny noise keeps its mean', bs.mean, 1e6, 1e-6)
K.near('and its deviation', bs.stddev, 1, 1e-6)
K.ok('variance is never negative', bs.variance >= 0, bs.variance)

process.exit(K.report('lab format'))
