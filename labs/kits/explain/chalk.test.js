// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the chalkboard's drawing model.
//
//     node labs/kits/explain/chalk.test.js
//
// What is worth pinning: an op's ink price (the renderer and the model agree
// on how far a half-drawn stroke reaches), and `at()` - it is the only thing
// standing between "the board fills up as the narration goes" and a drawing
// that jumps, goes backwards, or draws the answer before the question. The
// two drawings are checked for being inside their own box, because a stroke
// that leaves it is a stroke nobody ever sees.
const K = require('../kitcheck.js')

const C = K.load(__dirname, 'chalk.js',
    ['UNIT', 'HEAD', 'GLYPH', 'PAUSE_RATE', 'OPS', 'polyLength', 'arrowHeads',
     'rectPath', 'plotPoints', 'subOps', 'length', 'total', 'at', 'cut',
     'validate', 'transistorSection', 'gainGraph', 'SECTION', 'WORK'])

const LABELS = { n: 'N', p: 'P', collector: 'collector', base: 'base',
                 emitter: 'emitter', ib: 'I_B  0.8 mA', ic: 'I_C  9.8 mA' }
const GAIN = { ib: 'I_B', ic: 'I_C', beta: 'b = 12' }

K.section('length - what an op costs in ink')
K.near('a 3-4-5 line is five units long',
       C.length({ op: 'line', from: [0, 0], to: [30, 40] }), 50)
K.near('a rect is its perimeter',
       C.length({ op: 'rect', at: [0, 0], size: [10, 20] }), 60)
K.near('text is 18 per glyph',
       C.length({ op: 'text', at: [0, 0], text: 'abcd', size: 20 }), 72)
K.near('a pause costs a quarter of its milliseconds',
       C.length({ op: 'pause', ms: 1000 }), 250)
K.near('an arrow is its shaft plus two heads',
       C.length({ op: 'arrow', from: [0, 0], to: [100, 0] }), 100 + 2 * C.HEAD)
K.near('a curve is its polyline',
       C.length({ op: 'curve', points: [[0, 0], [0, 30], [40, 30]] }), 70)
K.near('a plot is its polyline, scaled into the box',
       C.length({ op: 'plot', at: [0, 0], size: [200, 100],
                  points: [[0, 0], [1, 0]] }), 200)
K.eq('an unknown op costs nothing', C.length({ op: 'scribble' }), 0)
K.eq('no op at all costs nothing', C.length(null), 0)

const AXES = { op: 'axes', at: [100, 100], size: [400, 200],
               xLabel: 'ab', yLabel: 'c' }
K.near('axes are both arrows plus the label glyphs', C.length(AXES),
       400 + 2 * C.HEAD + 200 + 2 * C.HEAD + C.GLYPH * 3)

K.section('total - the sum, nothing else')
const D = { width: 1000, height: 600, ops: [
    { op: 'line', from: [0, 0], to: [100, 0] },
    { op: 'pause', ms: 400 },
    { op: 'line', from: [100, 0], to: [100, 200] }
] }
K.near('total adds every op up', C.total(D), 100 + 100 + 200)
K.eq('an empty drawing costs nothing', C.total({ ops: [] }), 0)

K.section('at - what is on the board')
K.eq('nothing is drawn at progress 0', C.at(D, 0).length, 0)
K.eq('everything is drawn at progress 1', C.at(D, 1).length, 3)
K.ok('and all of it complete', C.at(D, 1).every(e => e.frac === 1))
K.eq('progress clamps below zero', C.at(D, -1).length, 0)
K.eq('progress clamps above one', C.at(D, 2).length, 3)
// 0.3 of 400 ink = 120: the first line (100) is done, the pause (100) is a
// fifth in, and nothing after it has started.
const mid = C.at(D, 0.3)
K.eq('mid-drawing: two entries', mid.length, 2)
K.eq('the finished one is the line', mid[0].op.op, 'line')
K.eq('and it is finished', mid[0].frac, 1)
K.eq('the cursor sits in the pause', mid[1].op.op, 'pause')
K.near('a fifth of the way through it', mid[1].frac, 0.2)
K.eq('exactly one op is part-drawn',
     mid.filter(e => e.frac > 0 && e.frac < 1).length, 1)
// The pause holds the cursor: at 0.4 the second line still has not started,
// which is the whole point of pricing a beat in ink.
K.eq('a pause consumes progress', C.at(D, 0.49).length, 2)
K.eq('and lets go once it is spent', C.at(D, 0.51).length, 3)

K.section('at - monotone')
const early = C.at(D, 0.4), later = C.at(D, 0.5)
K.ok('later shows at least as much', later.length >= early.length)
K.ok('and the same ops in the same order',
     early.every((e, i) => later[i].op === e.op))
K.ok('with fracs that never go backwards',
     early.every((e, i) => later[i].frac >= e.frac - 1e-12))

K.section('cut - a composite op, part-drawn')
K.eq('a primitive comes back as itself',
     C.cut({ op: 'line', from: [0, 0], to: [10, 0] }, 0.5).length, 1)
K.near('carrying its frac',
       C.cut({ op: 'line', from: [0, 0], to: [10, 0] }, 0.5)[0].frac, 0.5)
const whole = C.cut(AXES, 1)
K.eq('finished axes are four strokes', whole.length, 4)
K.ok('all of them complete', whole.every(e => e.frac === 1))
K.eq('the x arrow is drawn first', whole[0].op.to[0], 500)
const half = C.cut(AXES, 0.5)
K.ok('half-drawn axes are fewer, or end part-way',
     half.length < 4 || half[half.length - 1].frac < 1)
K.eq('and start with the x arrow', half[0].op.op, 'arrow')

K.section('the cross-section')
const sec = C.transistorSection(LABELS)
K.eq('well-formed', C.validate(sec).join('; '), '')
K.eq('it is laid out in the unit box', sec.width, C.UNIT.width)
K.eq('fourteen strokes', sec.ops.length, 14)
K.ok('every op name is known', sec.ops.every(o => C.OPS.indexOf(o.op) >= 0))
const texts = sec.ops.filter(o => o.op === 'text').map(o => o.text)
K.eq('the three terminals are named', ['collector', 'base', 'emitter']
     .filter(w => texts.indexOf(w) >= 0).length, 3)
K.eq('N appears twice - collector and emitter',
     texts.filter(t => t === 'N').length, 2)
K.eq('P once - the base', texts.filter(t => t === 'P').length, 1)
K.ok('both currents are labelled',
     texts.indexOf(LABELS.ib) >= 0 && texts.indexOf(LABELS.ic) >= 0)
K.eq('the three slabs are the first three ops',
     sec.ops.slice(0, 3).filter(o => o.op === 'rect').length, 3)
K.ok('the collector slab is the widest',
     C.SECTION.collector.size[0] > C.SECTION.emitter.size[0])
K.ok('the base is the thinnest',
     C.SECTION.base.size[1] < C.SECTION.collector.size[1]
     && C.SECTION.base.size[1] < C.SECTION.emitter.size[1])
K.ok('the emitter island sits on top',
     C.SECTION.emitter.at[1] + C.SECTION.emitter.size[1]
     <= C.SECTION.base.at[1] + 1e-9)
const pauseAt = sec.ops.findIndex(o => o.op === 'pause')
const arrows = sec.ops.map((o, i) => o.op === 'arrow' ? i : -1).filter(i => i >= 0)
K.eq('there are two current arrows', arrows.length, 2)
K.ok('structure is drawn before what moves', pauseAt >= 0 && pauseAt < arrows[0])
K.ok('the base arrow comes in from the left and ends inside the base slab',
     sec.ops[arrows[0]].from[0] < C.SECTION.base.at[0]
     && sec.ops[arrows[0]].to[0] > C.SECTION.base.at[0])
K.ok('the collector arrow runs up through the whole stack',
     sec.ops[arrows[1]].to[1] < C.SECTION.emitter.at[1]
     && sec.ops[arrows[1]].from[1] > C.SECTION.collector.at[1]
        + C.SECTION.collector.size[1])
K.eq('a missing label falls back to its own name',
     C.transistorSection({}).ops.filter(o => o.op === 'text' && o.text === 'emitter')
        .length, 1)

K.section('the gain graph')
const g = C.gainGraph(12, GAIN)
K.eq('well-formed', C.validate(g).join('; '), '')
K.eq('the axes come first', g.ops[0].op, 'axes')
K.eq('x is the base current', g.ops[0].xLabel, GAIN.ib)
K.eq('y is the collector current', g.ops[0].yLabel, GAIN.ic)
const plot = g.ops.find(o => o.op === 'plot')
K.eq('the line starts at the origin', plot.points[0][0] + plot.points[0][1], 0)
K.eq('three points: rise, knee, flat', plot.points.length, 3)
K.near('the top is flat past the knee', plot.points[2][1], plot.points[1][1])
K.ok('the knee is past the working point', plot.points[1][0] > 0.30)
K.ok('the flat top stays inside the axes', plot.points[1][1] < 1)
const marker = g.ops.find(o => o.op === 'rect')
K.near('the working point sits at x 0.3 of the axes',
       (marker.at[0] + marker.size[0] / 2 - 180) / 660, 0.30, 1e-9)
K.ok('and on the line, to within the rounding of beta',
     Math.abs((marker.at[1] + marker.size[1] / 2)
              - (490 - 0.30 * (plot.points[1][1] / plot.points[1][0]) * 400))
     < marker.size[1])
K.ok('the gain is written next to it',
     g.ops.some(o => o.op === 'text' && o.text === GAIN.beta))
K.eq('a nonsense beta falls back to the measured one',
     C.validate(C.gainGraph(0, GAIN)).join('; '), '')
K.eq('and so does a tiny one', C.validate(C.gainGraph(1, GAIN)).join('; '), '')
K.eq('and a huge one', C.validate(C.gainGraph(400, GAIN)).join('; '), '')

K.section('validate catches what it is for')
K.ok('an op nobody knows',
     C.validate({ width: 10, height: 10, ops: [{ op: 'scribble' }] }).length > 0)
K.ok('a stroke that leaves the box',
     C.validate({ width: 100, height: 100,
                  ops: [{ op: 'line', from: [0, 0], to: [200, 0] }] }).length > 0)
K.ok('a NaN coordinate',
     C.validate({ width: 100, height: 100,
                  ops: [{ op: 'line', from: [0, 0], to: [NaN, 0] }] }).length > 0)
K.ok('a plot point outside axes units',
     C.validate({ width: 100, height: 100,
                  ops: [{ op: 'plot', at: [0, 0], size: [10, 10],
                          points: [[0, 0], [2, 0]] }] }).length > 0)
K.ok('no unit box at all', C.validate(null).length > 0)

process.exit(K.report('explain kit chalk'))
