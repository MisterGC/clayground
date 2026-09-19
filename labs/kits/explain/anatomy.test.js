// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the explain kit's transistor anatomy.
//
//     node labs/kits/explain/anatomy.test.js
//
// What is worth pinning: the pads match the circuit kit (the anatomy has to
// stand where the kit's transistor stood), the lesson order covers every
// explained part exactly once, and the exploded die layers do not collide -
// a finger has to be able to land on each one.
const K = require('../kitcheck.js')

const A = K.load(__dirname, 'anatomy.js',
    ['PADS', 'PAD_OFFSET', 'BODY', 'DIE', 'PARTS', 'partById', 'partIds',
     'explainOrder', 'offsetAt', 'dieStack', 'validate'])

K.section('table')
K.eq('validate() finds nothing wrong', A.validate().join('; '), '')
K.eq('eleven parts', A.PARTS.length, 11)
K.eq('ids are unique', new Set(A.partIds()).size, A.PARTS.length)
K.eq('unknown id is null', A.partById('nope'), null)

K.section('pads - the circuit kit\'s geometry')
K.eq('pad offset is the kit\'s 3.5', A.PAD_OFFSET, 3.5)
K.eq('collector pad left', A.PADS.collector.x, -3.5)
K.eq('emitter pad right', A.PADS.emitter.x, 3.5)
K.eq('base pad on the near side', A.PADS.base.z, 3.5)
K.eq('pads sit on the board', A.PADS.base.y, 0.62)

K.section('lesson order')
const order = A.explainOrder()
K.eq('eight explained parts', order.length, 8)
K.eq('legs first, collector leg leads', order[0], 'leg.collector')
K.eq('the case is opened before the die', order[3], 'case')
K.eq('the die is taught bottom-up: collector', order[4], 'die.collector')
K.eq('then base', order[5], 'die.base')
K.eq('then emitter', order[6], 'die.emitter')
K.eq('wires last', order[7], 'wires')
K.ok('print is never explained', order.indexOf('print') < 0)

K.section('offsets')
K.eq('assembled means no displacement', A.offsetAt('case', 0).y, 0)
K.near('half spread is half the way', A.offsetAt('case', 0.5).y, 4.25)
K.eq('spread clamps above 1', A.offsetAt('case', 3).y, 8.5)
K.eq('spread clamps below 0', A.offsetAt('case', -1).y, 0)
K.eq('an unknown part does not move', A.offsetAt('nope', 1).y, 0)
K.eq('spread defaults to full', A.offsetAt('wires').y, 6.2)

K.section('die stack')
const stack = A.dieStack(1.0)
K.eq('three layers', stack.length, 3)
K.eq('collector is N', stack[0].doping, 'n')
K.eq('base is P', stack[1].doping, 'p')
K.eq('emitter is N', stack[2].doping, 'n')
K.near('layers are contiguous', stack[1].y0, stack[0].y1)
K.near('stack height is the sum of the layers', stack[2].y1 - 1.0, 0.6 + 0.2 + 0.4)
K.ok('emitter is an island, smaller than the die', stack[2].footprint < A.DIE.footprint)
K.ok('the die fits inside the case', A.DIE.footprint < A.BODY.radius * 2)

// At full spread the exploded die layers must not overlap in y: each one
// rises by its offset, and the gaps have to be at least a layer thick so
// each can be pointed at on its own.
K.section('exploded layers do not collide')
const exploded = stack.map(l => {
    const o = A.offsetAt('die.' + l.layer, 1)
    return { layer: l.layer, y0: l.y0 + o.y, y1: l.y1 + o.y }
})
K.ok('base clears collector', exploded[1].y0 > exploded[0].y1 + 0.2,
     JSON.stringify(exploded))
K.ok('emitter clears base', exploded[2].y0 > exploded[1].y1 + 0.2)
const caseTop = A.offsetAt('case', 1).y
K.ok('the case rises above the wires', caseTop > A.offsetAt('wires', 1).y + 1)

process.exit(K.report('explain kit anatomy'))
