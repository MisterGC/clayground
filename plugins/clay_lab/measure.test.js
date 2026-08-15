// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/measure.test.js
//
// The tape measure's arithmetic. Every number the overlay writes on screen is
// computed here, so it can be checked against a triangle whose sides and
// angles are known by hand rather than against a screenshot.

const K = require('../../labs/kits/kitcheck.js')
const M = K.load(__dirname, 'measure.js',
    ['distance', 'midpoint', 'segments', 'total', 'angleAt', 'vertices',
     'angleText', 'readout'])
const F = K.load(__dirname, 'format.js', ['qty'])

function p(x, z, y) { return { x: x, y: y === undefined ? 0 : y, z: z } }

// The 3-4-5 corner, laid out so the answers are the ones from the textbook:
// legs of 4 and 5 about a vertex whose cosine is 0.8, i.e. 36.87 degrees.
const bend = [p(4, 0), p(0, 0), p(4, 3)]

// ------------------------------------------------------------------ lengths

K.section('lengths')

K.near('a straight run measures its side', M.distance(p(0, 0), p(4, 0)), 4)
K.near('and the hypotenuse of a 3-4-5', M.distance(p(0, 0), p(4, 3)), 5)
K.near('a point is no distance from itself', M.distance(p(2, 7), p(2, 7)), 0)
K.near('height counts too', M.distance(p(0, 0, 0), p(0, 0, 3)), 3)

K.eq('one point is no segments', M.segments([p(0, 0)]).length, 0)
K.eq('nothing at all is no segments', M.segments(null).length, 0)
K.eq('three points chain into two segments', M.segments(bend).length, 2)
K.near('the first leg', M.segments(bend)[0].length, 4)
K.near('the second', M.segments(bend)[1].length, 5)
K.near('and the total is the walk, not the shortcut', M.total(bend), 9)
K.near('a lone point totals nothing', M.total([p(1, 1)]), 0)

K.section('label positions')

const mid = M.segments(bend)[0].mid
K.near('a leg is labelled at its middle, x', mid.x, 2)
K.near('and z', mid.z, 0)

// ------------------------------------------------------------------- angles

K.section('angles')

K.near('the corner of the 3-4-5, in degrees', M.angleAt(bend, 1), 36.8698976, 1e-6)
K.eq('the first point has no corner', M.angleAt(bend, 0), null)
K.eq('nor does the last', M.angleAt(bend, 2), null)

const square = [p(0, 4), p(0, 0), p(4, 0)]
K.near('a right-angled turn reads 90', M.angleAt(square, 1), 90)

// The interior angle: 180 is straight on, 0 is folded back - the reading a
// hand expects from a protractor laid into the corner.
const straight = [p(-3, 0), p(0, 0), p(7, 0)]
K.near('a point in line with its neighbours reads 180', M.angleAt(straight, 1), 180)
const folded = [p(5, 0), p(0, 0), p(9, 0)]
K.near('a chain folded back on itself reads 0', M.angleAt(folded, 1), 0)

// acos(1.0000000000000002) is NaN, which is how a straight line used to come
// out blank instead of as 180.
K.ok('a collinear run never produces NaN', isFinite(M.angleAt(straight, 1)))

K.eq('a doubled point has no angle to give',
     M.angleAt([p(0, 0), p(0, 0), p(3, 0)], 1), null)

K.eq('two points have no interior vertices', M.vertices([p(0, 0), p(1, 0)]).length, 0)
K.eq('three have one', M.vertices(bend).length, 1)
K.eq('and it knows which one it is', M.vertices(bend)[0].i, 1)
K.eq('four points have two corners',
     M.vertices([p(0, 0), p(4, 0), p(4, 4), p(0, 4)]).length, 2)

// --------------------------------------------------------------- formatting

K.section('formatting')

K.eq('an angle is written to one decimal', M.angleText(36.8698976), '36.9°')
K.eq('a whole one keeps its decimal', M.angleText(90), '90.0°')
K.eq('German writes it with a comma', M.angleText(36.8698976, ','), '36,9°')
K.eq('a rounding artefact never prints as minus zero',
     M.angleText(-0.001), '0.0°')

// ------------------------------------------------------------- the read-out

K.section('the read-out')

const metres = (d) => F.qty(d, 'm', 1)
const r = M.readout(bend, metres)

K.eq('every leg carries its own label', r.segments.length, 2)
K.eq('the first reads', r.segments[0].text, '4.0 m')
K.eq('the second', r.segments[1].text, '5.0 m')
K.eq('the corner reads', r.vertices[0].text, '36.9°')
K.near('the total adds them up', r.total, 9)
K.eq('and is written out', r.totalText, '9.0 m')
K.near('beside the last point', r.totalAt.z, 3)

// One leg needs no total: it would be the same number twice, one line apart.
const one = M.readout([p(0, 0), p(4, 0)], metres)
K.eq('a single leg still has its length', one.segments[0].text, '4.0 m')
K.eq('but no total', one.totalAt, null)
K.eq('and no total text', one.totalText, '')

const none = M.readout([], metres)
K.eq('an empty run has no segments', none.segments.length, 0)
K.eq('no corners', none.vertices.length, 0)
K.eq('and no total', none.totalAt, null)

// The unit is the lab's: the same distance is metres in a street plan and
// millimetres on a circuit board, and the arithmetic does not care.
K.eq('the formatter owns the unit',
     M.readout(bend, (d) => F.qty(d, 'mm', 0)).segments[0].text, '4 mm')
K.eq('without one it is a bare number', M.readout(bend).segments[0].text, '4')

process.exit(K.report('lab measure'))
