// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/explode.test.js
//
// The part-table algebra of ExplodedView3D, with no engine: staged travel,
// the lesson order, what dims around a focus in a nested table, which parts
// get a label, how a segment is cut into dashes, and what validate() refuses.
// A subject's own table (a kit's anatomy.js) is checked against the same
// rules, so a table that passes here can be handed to the view.

const K = require('../../labs/kits/kitcheck.js')
const E = K.load(__dirname, 'explode.js',
    ['travelAt', 'displacement', 'stagesOf', 'rowOf', 'idsInOrder', 'ancestorsOf',
     'descendantsOf', 'dimmedIds', 'labelledIds', 'labelOf', 'dashes', 'validate'])

// A valve-shaped table: a body that stays, two flanges that leave sideways
// in stage 1, a handwheel that lifts off in stage 1 and comes apart in
// stage 2, and a stem that rises out of the body in stage 2.
const T = [
    { id: "body",      parent: "",          role: "iron",  order: 1, stage: 1, offset: { x: 0,    y: 0,   z: 0 }, anchor: { x: 0, y: 0.75, z: 0 } },
    { id: "flange.in", parent: "",          role: "steel", order: 2, stage: 1, offset: { x: -2.5, y: 0,   z: 0 }, anchor: { x: 0, y: 0, z: 0 } },
    { id: "flange.out",parent: "",          role: "steel", order: 3, stage: 1, offset: { x: 2.5,  y: 0,   z: 0 }, anchor: { x: 0, y: 0, z: 0 } },
    { id: "stem",      parent: "",          role: "steel", order: 4, stage: 2, offset: { x: 0,    y: 2.0, z: 0 }, anchor: { x: 0, y: 0.4, z: 0 } },
    { id: "wheel",     parent: "",          role: "iron",  order: 5, stage: 1, offset: { x: 0,    y: 4.5, z: 0 }, anchor: { x: 0, y: 0, z: 0 } },
    { id: "wheel.rim", parent: "wheel",     role: "iron",  order: 6, stage: 2, offset: { x: 0,    y: 1.2, z: 0 }, anchor: { x: 0, y: 0, z: 1.3 } },
    { id: "wheel.hub", parent: "wheel",     role: "iron",  order: 0, stage: 2, offset: { x: 0,    y: 0,   z: 0 }, anchor: { x: 0, y: 0, z: 0 } },
    { id: "plate",     parent: "",          role: "print", order: 0, stage: 1, offset: { x: 0,    y: 0,   z: 2.0 }, anchor: { x: 0, y: 0, z: 0 } }
]

K.section('the table validates')
K.eq('validate() finds nothing wrong', E.validate(T).join('; '), '')
K.eq('two stages', E.stagesOf(T), 2)
K.eq('a table with no stages has one', E.stagesOf([{ id: "a", offset: { x: 0, y: 0, z: 0 } }]), 1)
K.eq('an empty table has one stage', E.stagesOf([]), 1)
K.eq('rowOf finds a row', E.rowOf(T, 'stem').order, 4)
K.eq('rowOf answers null for a stranger', E.rowOf(T, 'nope'), null)

K.section('staged travel')
K.eq('assembled means no travel', E.travelAt(1, 0), 0)
K.near('half spread is half the way through stage 1', E.travelAt(1, 0.5), 0.5)
K.eq('stage 1 is over at spread 1', E.travelAt(1, 1), 1)
K.eq('stage 1 stays out through stage 2', E.travelAt(1, 1.7), 1)
K.eq('stage 2 has not begun at spread 1', E.travelAt(2, 1), 0)
K.near('stage 2 is half way at 1.5', E.travelAt(2, 1.5), 0.5)
K.eq('spread clamps below 0', E.travelAt(1, -3), 0)
K.eq('spread clamps above the last stage', E.travelAt(2, 9), 1)
K.eq('an undeclared stage is stage 1', E.travelAt(undefined, 1), 1)
K.eq('a stage below 1 is stage 1', E.travelAt(0, 1), 1)

K.section('displacement')
K.near('a flange half way out', E.displacement(T[1].offset, 1, 0.5).x, -1.25)
K.near('unit scales the travel', E.displacement(T[1].offset, 1, 1, 2).x, -5)
K.eq('the stem has not moved at spread 1', E.displacement(T[3].offset, 2, 1).y, 0)
K.near('the stem is out at spread 2', E.displacement(T[3].offset, 2, 2).y, 2)
K.eq('no offset means no travel', E.displacement(undefined, 1, 1).y, 0)

K.section('lesson order')
K.eq('six explained parts, in order',
     E.idsInOrder(T).join(','), 'body,flange.in,flange.out,stem,wheel,wheel.rim')
K.ok('the hub is never explained', E.idsInOrder(T).indexOf('wheel.hub') < 0)
K.eq('equal orders keep table order',
     E.idsInOrder([{ id: "b", order: 1 }, { id: "a", order: 1 }]).join(','), 'b,a')

K.section('nesting')
K.eq('the rim sits in the wheel', E.ancestorsOf(T, 'wheel.rim').join(','), 'wheel')
K.eq('a top-level part has no ancestors', E.ancestorsOf(T, 'body').length, 0)
K.eq('the wheel holds the rim and the hub', E.descendantsOf(T, 'wheel').join(','), 'wheel.rim,wheel.hub')
K.eq('a leaf holds nothing', E.descendantsOf(T, 'stem').length, 0)

K.section('what dims around a focus')
K.eq('no focus dims nothing', E.dimmedIds(T, '').length, 0)
const dimStem = E.dimmedIds(T, 'stem')
K.ok('everything but the stem dims', dimStem.indexOf('stem') < 0 && dimStem.length === T.length - 1)
const dimRim = E.dimmedIds(T, 'wheel.rim')
K.ok('the rim stays lit', dimRim.indexOf('wheel.rim') < 0)
K.ok('the wheel it sits in stays lit (opacity inherits)', dimRim.indexOf('wheel') < 0)
K.ok('the hub beside it dims', dimRim.indexOf('wheel.hub') >= 0)
const dimWheel = E.dimmedIds(T, 'wheel')
K.ok('focusing the wheel keeps its parts', dimWheel.indexOf('wheel.rim') < 0 && dimWheel.indexOf('wheel.hub') < 0)
K.ok('and dims the body', dimWheel.indexOf('body') >= 0)

K.section('labels')
K.eq('"all" is the lesson order', E.labelledIds(T, 'all').join(','), E.idsInOrder(T).join(','))
K.eq('a list keeps its order', E.labelledIds(T, ['stem', 'body']).join(','), 'stem,body')
K.eq('a stranger in the list is skipped', E.labelledIds(T, ['stem', 'nope']).join(','), 'stem')
K.eq('nothing labelled', E.labelledIds(T, []).length, 0)
K.eq('null is nothing', E.labelledIds(T, null).length, 0)
K.eq('a label from the dictionary', E.labelOf('stem', { stem: 'Spindel' }), 'Spindel')
K.eq('the id when the dictionary is silent', E.labelOf('stem', {}), 'stem')
K.eq('the id when there is no dictionary', E.labelOf('stem', undefined), 'stem')
K.eq('an empty entry falls back to the id', E.labelOf('stem', { stem: '' }), 'stem')

K.section('dashes')
const ds = E.dashes({ x: 0, y: 0, z: 0 }, { x: 0, y: 3, z: 0 }, 0.5, 0.5)
K.eq('three dashes over three units at 0.5 + 0.5', ds.length, 3)
K.near('the first dash starts at the assembled end', ds[0][0].y, 0)
K.near('and is a dash long', ds[0][1].y, 0.5)
K.near('the second starts after the gap', ds[1][0].y, 1)
const clipped = E.dashes({ x: 0, y: 0, z: 0 }, { x: 1.2, y: 0, z: 0 }, 0.5, 0.5)
K.eq('a partial last dash is drawn', clipped.length, 2)
K.near('and clipped at the end', clipped[1][1].x, 1.2)
K.eq('a part that has not moved has no line', E.dashes({ x: 1, y: 1, z: 1 }, { x: 1, y: 1, z: 1.01 }, 0.5, 0.5).length, 0)
const diag = E.dashes({ x: 0, y: 0, z: 0 }, { x: 3, y: 4, z: 0 }, 1, 0)
K.eq('no gap means the dashes tile the line', diag.length, 5)
K.near('dashes run along the segment', diag[4][1].x, 3)
K.near('in y as well', diag[4][1].y, 4)

K.section('validate() refuses')
function bad(rows) { return E.validate(rows).join('; ') }
K.ok('a duplicate id', bad([{ id: "a", offset: { x: 0, y: 0, z: 0 } }, { id: "a", offset: { x: 0, y: 0, z: 0 } }]).indexOf('duplicate id a') >= 0)
K.ok('a missing id', bad([{ offset: { x: 0, y: 0, z: 0 } }]).indexOf('no id') >= 0)
K.ok('an unknown parent', bad([{ id: "a", parent: "zz", offset: { x: 0, y: 0, z: 0 } }]).indexOf('unknown parent zz') >= 0)
K.ok('a cycle', bad([{ id: "a", parent: "b", offset: { x: 0, y: 0, z: 0 } },
                    { id: "b", parent: "a", offset: { x: 0, y: 0, z: 0 } }]).indexOf('cycle') >= 0)
K.ok('a part that is its own parent', bad([{ id: "a", parent: "a", offset: { x: 0, y: 0, z: 0 } }]).indexOf('cycle') >= 0)
K.ok('a gap in the order', bad([{ id: "a", order: 1, offset: { x: 0, y: 0, z: 0 } },
                               { id: "b", order: 3, offset: { x: 0, y: 0, z: 0 } }]).indexOf('order is not 1..2') >= 0)
K.ok('a fractional order', bad([{ id: "a", order: 1.5, offset: { x: 0, y: 0, z: 0 } }]).indexOf('whole number') >= 0)
K.ok('a stage of 0', bad([{ id: "a", stage: 0, offset: { x: 0, y: 0, z: 0 } }]).indexOf('stage below 1') >= 0)
K.ok('a non-finite offset', bad([{ id: "a", offset: { x: NaN, y: 0, z: 0 } }]).indexOf('non-finite offset') >= 0)
K.ok('a non-finite anchor', bad([{ id: "a", offset: { x: 0, y: 0, z: 0 }, anchor: { x: 0, y: Infinity, z: 0 } }]).indexOf('non-finite anchor') >= 0)
K.eq('a row with only an id and an offset is fine', bad([{ id: "a", offset: { x: 0, y: 0, z: 0 } }]), '')

process.exit(K.report('exploded view part table'))
