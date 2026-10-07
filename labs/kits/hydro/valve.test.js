// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the hydro kit's valve anatomy.
//
//     node labs/kits/hydro/valve.test.js
//
// What is worth pinning: the kernel accepts this table as its own (same
// validate, same stage count, same teaching order - the whole claim of
// #274 is that a second subject needs no edit to the block), the lesson
// walks the valve from the outside in, and at full spread no piece is left
// sitting inside another - a mark or a fingertip has to be able to land on
// each one.
const path = require('path')
const K = require('../kitcheck.js')

const V = K.load(__dirname, 'valve.js',
    ['BODY', 'FLANGE', 'STEM', 'WHEEL', 'PLATE', 'ROLES', 'PARTS',
     'partById', 'partIds', 'explainOrder', 'travelAt', 'offsetAt', 'validate'])

// The kernel's algebra, loaded from the plugin it lives in: the table is
// checked by the rules the view itself applies, not by a copy of them.
const E = K.load(path.join(__dirname, '..', '..', '..', 'plugins', 'clay_lab'),
                 'explode.js', ['validate', 'stagesOf', 'idsInOrder'])

K.section('table')
K.eq('validate() finds nothing wrong', V.validate().join('; '), '')
K.eq('eight parts', V.PARTS.length, 8)
K.eq('ids are unique', new Set(V.partIds()).size, V.PARTS.length)
K.eq('unknown id is null', V.partById('nope'), null)
K.ok('every role is one the table declares',
     V.PARTS.every(p => V.ROLES.indexOf(p.role) >= 0))

K.section('the kernel accepts the same rows')
K.eq('explode.js validate() finds nothing wrong', E.validate(V.PARTS).join('; '), '')
K.eq('two stages', E.stagesOf(V.PARTS), 2)
K.eq('and the kernel walks the same lesson',
     E.idsInOrder(V.PARTS).join('|'), V.explainOrder().join('|'))

K.section('the sub-assembly')
K.eq('the rim sits inside the handwheel', V.partById('handwheel.rim').parent, 'handwheel')
K.eq('the spokes too', V.partById('handwheel.spokes').parent, 'handwheel')
K.eq('the handwheel itself is top level', V.partById('handwheel').parent, '')
K.ok('every other part is top level',
     V.PARTS.filter(p => p.parent !== '').length === 2)

K.section('lesson order')
const order = V.explainOrder()
K.eq('six explained parts', order.length, 6)
K.eq('the body first', order[0], 'body')
K.eq('then the inlet flange', order[1], 'flange.in')
K.eq('then the outlet flange', order[2], 'flange.out')
K.eq('then the stem', order[3], 'stem')
K.eq('then the handwheel', order[4], 'handwheel')
K.eq('and last the rim inside it', order[5], 'handwheel.rim')
K.ok('the spokes are never explained on their own', order.indexOf('handwheel.spokes') < 0)
K.ok('the printed plate is never explained', order.indexOf('plate') < 0)

K.section('stages')
K.eq('assembled means no displacement', V.offsetAt('handwheel', 0).y, 0)
K.eq('the handwheel is up at spread 1', V.offsetAt('handwheel', 1).y, 4.0)
K.eq('the stem has not moved at spread 1', V.offsetAt('stem', 1).y, 0)
K.near('half way into stage 2 is half the stem travel', V.offsetAt('stem', 1.5).y, 1.6)
K.eq('the stem is out at spread 2', V.offsetAt('stem', 2).y, 3.2)
K.eq('the rim lifts off the spokes in stage 2', V.offsetAt('handwheel.rim', 2).y, 1.2)
K.eq('the spokes stay where the handwheel put them', V.offsetAt('handwheel.spokes', 2).y, 0)
K.eq('the handwheel does not travel twice', V.offsetAt('handwheel', 2).y, 4.0)
K.eq('spread clamps below 0', V.offsetAt('handwheel', -1).y, 0)
K.eq('spread clamps above the last stage', V.offsetAt('stem', 5).y, 3.2)
K.eq('an unknown part does not move', V.offsetAt('nope', 2).y, 0)

// At full spread every piece must stand on its own: the rig looks from +z
// and above, so what matters is the gaps in y between the column's pieces
// and the gap in x between the flanges and the body they left.
K.section('nothing overlaps at spread 2')
const stemTop = V.STEM.y + V.STEM.height * 0.5 + V.offsetAt('stem', 2).y
const wheelY = V.WHEEL.y + V.offsetAt('handwheel', 2).y
const spokeBottom = wheelY + V.WHEEL.spokeY
const spokeTop = wheelY + V.WHEEL.spokeY + V.WHEEL.spokeHeight
const rimBottom = wheelY + V.offsetAt('handwheel.rim', 2).y - V.WHEEL.rimHeight * 0.5
K.ok('the stem top stays below the lifted handwheel', stemTop < spokeBottom - 0.5,
     'stem top ' + stemTop + ', handwheel bottom ' + spokeBottom)
K.ok('and above the body it came out of', stemTop > V.BODY.y + V.BODY.height)
K.ok('the rim clears the spokes', rimBottom > spokeTop + 0.5,
     'rim bottom ' + rimBottom + ', spokes top ' + spokeTop)
// the inlet flange sits at -FLANGE.x and travels further out from there
const flangeInner = Math.abs(-V.FLANGE.x + V.offsetAt('flange.in', 2).x) - V.FLANGE.length * 0.5
K.ok('the flanges clear the body', flangeInner > V.BODY.width * 0.5 + 0.5,
     'nearest flange face at ' + flangeInner)
K.eq('they leave in opposite directions',
     Math.sign(V.offsetAt('flange.in', 2).x), -Math.sign(V.offsetAt('flange.out', 2).x))
K.ok('nothing but the flat plate travels toward the camera',
     V.PARTS.every(p => p.id === 'plate' || p.offset.z <= 0))
K.ok('the plate leaves the body\'s silhouette',
     V.PLATE.z + V.offsetAt('plate', 2).z - V.PLATE.depth * 0.5 > V.BODY.depth * 0.5)

K.section('anchors')
K.ok('every anchor is finite',
     V.PARTS.every(p => isFinite(p.anchor.x) && isFinite(p.anchor.y) && isFinite(p.anchor.z)))
K.eq('the body is marked on its front top edge', V.partById('body').anchor.z, V.BODY.depth * 0.5)
K.eq('the stem is marked on its top', V.partById('stem').anchor.y, V.STEM.height * 0.5)
K.eq('the handwheel is marked on the near side of its rim',
     V.partById('handwheel').anchor.z, V.WHEEL.rimRadius)

process.exit(K.report('hydro kit valve'))
