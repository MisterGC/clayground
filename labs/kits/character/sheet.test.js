// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the character kit's sheet model.
//
//     node labs/kits/character/sheet.test.js
//
// sheet.js is Qt-free (`.pragma library`) precisely so it can be checked
// here with no engine. What it covers is what a lab quotes: where the
// figures of a sheet stand, what a phase is called, the distance between two
// faces, and the boxes-per-character claim the crowd scenario is measured
// against.
const K = require('../kitcheck.js')

const S = K.load(__dirname, 'sheet.js',
                 ['phaseKind', 'phaseOf', 'layout', 'EXPRESSIONS', 'FACE_KEYS',
                  'faceDistance', 'distinctness', 'GESTURES', 'gestureNamed',
                  'BUILDS', 'buildNamed', 'BOXES', 'expectedDraws',
                  'drawsPerCharacter'])
const T = K.load(__dirname, 'strings.js', ['dict'])

K.section('phases')
K.eq('t=0 is a contact', S.phaseKind(0), 'contact')
K.eq('t=0.5 is a contact', S.phaseKind(0.5), 'contact')
K.eq('t=1 wraps to a contact', S.phaseKind(1), 'contact')
K.eq('t=0.25 is passing', S.phaseKind(0.25), 'passing')
K.eq('t=0.75 is passing', S.phaseKind(0.75), 'passing')
K.eq('t=0.125 is neither', S.phaseKind(0.125), '')
K.near('phase of 1.0 s in a 0.8 s cycle', S.phaseOf(1.0, 0.8), 0.25, 1e-9)
K.near('phase wraps', S.phaseOf(1.6, 0.8), 0, 1e-9)
K.eq('no cycle, no phase', S.phaseOf(3, 0), 0)

K.section('layout')
const row = S.layout(4, 7.5)
K.eq('four figures', row.xs.length, 4)
K.near('centred: first', row.xs[0], -11.25, 1e-9)
K.near('centred: last', row.xs[3], 11.25, 1e-9)
K.near('centred: sum is zero', row.xs.reduce((a, b) => a + b, 0), 0, 1e-9)
K.near('span covers a spacing per figure', row.span, 30, 1e-9)
K.near('a single figure stands at the origin', S.layout(1, 7.5).xs[0], 0, 1e-9)

K.section('faces')
K.eq('six expressions', S.EXPRESSIONS.length, 6)
K.eq('ten face numbers', S.FACE_KEYS.length, 10)
const neutral = { cornerLift: 0, skew: 0, open: 0, wide: 0, round: 0,
                  hood: 0, squint: 0, browAngle: 0, browRise: 0, browSkew: 0 }
const happy = Object.assign({}, neutral, { cornerLift: 0.6, squint: 0.3 })
const angry = Object.assign({}, neutral, { browAngle: 30, cornerLift: -0.3 })
K.near('identical faces are 0 apart', S.faceDistance(neutral, neutral), 0)
K.near('happy vs neutral', S.faceDistance(neutral, happy), Math.hypot(0.6, 0.3), 1e-9)
K.near('thirty degrees of brow count as one unit',
       S.faceDistance(neutral, angry), Math.hypot(1, 0.3), 1e-9)
K.near('distinctness is the closest pair', S.distinctness([neutral, happy, angry]),
       Math.hypot(0.6, 0.3), 1e-9)
K.eq('a duplicate face makes the set indistinct', S.distinctness([neutral, happy, neutral]), 0)
K.eq('one face has no distinctness', S.distinctness([neutral]), 0)

K.section('gestures')
K.ok('thirteen columns', S.GESTURES.length === 13)
K.eq('point is a solver gesture', S.gestureNamed('point').kind, 'gesture')
K.eq('jab is a frozen fight phase', S.gestureNamed('jab').action, 'fight')
K.ok('every action column has a phase in [0,1]',
     S.GESTURES.filter(g => g.kind === 'action').every(g => g.at >= 0 && g.at <= 1))
K.eq('unknown gesture is null', S.gestureNamed('wave'), null)

K.section('builds')
K.eq('six builds', S.BUILDS.length, 6)
K.ok('every slider inside 0..1',
     S.BUILDS.every(b => [b.maturity, b.femininity, b.mass, b.muscle, b.realism]
                          .every(v => v >= 0 && v <= 1)))
K.ok('every height is a height', S.BUILDS.every(b => b.bodyHeight > 0))
K.eq('the child is the short one', S.buildNamed('child').bodyHeight, 6)
K.eq('unknown build is null', S.buildNamed('giant'), null)

K.section('crowd')
K.eq('twenty at Low', S.expectedDraws(20, 'low'), 440)
K.eq('twenty at High', S.expectedDraws(20, 'high'), 880)
K.eq('unknown tier draws nothing', S.expectedDraws(20, 'ultra'), 0)
K.near('draws per character takes the floor off the top',
       S.drawsPerCharacter(445, 5, 20), 22, 1e-9)
K.eq('no characters, no per-character', S.drawsPerCharacter(5, 5, 0), 0)

K.section('strings')
const en = Object.keys(T.dict.en).sort(), de = Object.keys(T.dict.de).sort()
K.eq('EN and DE carry the same keys', JSON.stringify(en), JSON.stringify(de))
K.ok('every expression has a name', S.EXPRESSIONS.every(e => T.dict.en['face.' + e]))
K.ok('every gesture has a name', S.GESTURES.every(g => T.dict.en['gesture.' + g.name]))
K.ok('every build has a name', S.BUILDS.every(b => T.dict.en['build.' + b.name]))

process.exit(K.report('character kit'))
