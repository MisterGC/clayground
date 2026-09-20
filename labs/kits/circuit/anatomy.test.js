// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the circuit kit's transistor anatomy.
//
//     node labs/kits/circuit/anatomy.test.js
//
// What is worth pinning: the pads match the kit's own part (the anatomy has
// to stand where CircuitElement3D's transistor stood), the lesson order
// covers every explained part exactly once, the two stages open in the right
// order, and the exploded die layers do not collide - a finger has to be able
// to land on each one.
//
// The table is also run past the KERNEL's rules, from plugins/clay_lab, so a
// row this kit writes and a row ExplodedView3D can use stay the same thing.
const path = require('path')
const K = require('../kitcheck.js')

const A = K.load(__dirname, 'anatomy.js',
    ['PADS', 'PAD_OFFSET', 'BODY', 'FACE', 'HEADER', 'DIE', 'ROLES', 'PARTS',
     'partById', 'partIds', 'explainOrder', 'stageCount', 'offsetAt',
     'dieStack', 'validate'])

const E = K.load(path.join(__dirname, '..', '..', '..', 'plugins', 'clay_lab'),
    'explode.js', ['validate', 'stagesOf', 'idsInOrder'])

K.section('table')
K.eq('validate() finds nothing wrong', A.validate().join('; '), '')
K.eq('eleven parts', A.PARTS.length, 11)
K.eq('ids are unique', new Set(A.partIds()).size, A.PARTS.length)
K.eq('unknown id is null', A.partById('nope'), null)

K.section('the kernel accepts the table')
K.eq('explode.js validate() finds nothing wrong', E.validate(A.PARTS).join('; '), '')
K.eq('two stages', E.stagesOf(A.PARTS), 2)
K.eq('the kit and the kernel agree about the stage count', A.stageCount(),
     E.stagesOf(A.PARTS))
K.eq('the kernel walks the same lesson order',
     E.idsInOrder(A.PARTS).join(','), A.explainOrder().join(','))

K.section('pads - the kit\'s geometry')
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
K.eq('spread clamps above the last stage', A.offsetAt('case', 3).y, 8.5)
K.eq('spread clamps below 0', A.offsetAt('case', -1).y, 0)
K.eq('an unknown part does not move', A.offsetAt('nope', 1).y, 0)
K.eq('no spread means fully apart', A.offsetAt('wires').y, 6.2)

// The shell comes off first and the inside stays put while it does, which is
// the whole reason the table carries a stage at all.
K.section('stages')
K.eq('the case is out at spread 1', A.offsetAt('case', 1).y, 8.5)
K.eq('the facet is out at spread 1', A.offsetAt('face', 1).x, 3.0)
K.eq('the collector leg is out at spread 1', A.offsetAt('leg.collector', 1).x, -1.5)
K.eq('the die has not moved at spread 1', A.offsetAt('die.base', 1).y, 0)
K.eq('the header has not moved at spread 1', A.offsetAt('header', 1).y, 0)
K.eq('the wires have not moved at spread 1', A.offsetAt('wires', 1).y, 0)
K.near('the die is half out at spread 1.5', A.offsetAt('die.base', 1.5).y, 1.9)
K.eq('the die is out at spread 2', A.offsetAt('die.base', 2).y, 3.8)
K.eq('the case is still out at spread 2', A.offsetAt('case', 2).y, 8.5)

K.section('anchors')
for (const p of A.PARTS) {
    K.ok('anchor of ' + p.id + ' is finite',
         p.anchor && isFinite(p.anchor.x) && isFinite(p.anchor.y) && isFinite(p.anchor.z),
         JSON.stringify(p.anchor))
}
K.ok('the print is marked at its near edge, not under the part', A.PARTS[0].anchor.z > 3)
K.near('the case is marked on its rim', A.partById('case').anchor.y, A.BODY.height * 0.5)
K.near('a die layer is marked on its top face',
       A.partById('die.base').anchor.y, A.DIE.layers.base.thickness)

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
const full = A.stageCount()
const exploded = stack.map(l => {
    const o = A.offsetAt('die.' + l.layer, full)
    return { layer: l.layer, y0: l.y0 + o.y, y1: l.y1 + o.y }
})
K.ok('base clears collector', exploded[1].y0 > exploded[0].y1 + 0.2,
     JSON.stringify(exploded))
K.ok('emitter clears base', exploded[2].y0 > exploded[1].y1 + 0.2)
const caseTop = A.offsetAt('case', full).y
K.ok('the case rises above the wires', caseTop > A.offsetAt('wires', full).y + 1)
// From +z, anything that comes toward the camera hides the column behind it.
K.ok('the facet leaves the die column sideways, not forward',
     Math.abs(A.offsetAt('face', full).x) > 2 && A.offsetAt('face', full).z < 1.5)

process.exit(K.report('circuit kit anatomy'))
