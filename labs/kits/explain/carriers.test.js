// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit suite for the explain kit's carrier model.
//
//     node labs/kits/explain/carriers.test.js
//
// What is worth pinning: the die this file travels through is the die
// anatomy.js describes (the two are loaded side by side and compared - a
// thickness changed in one place only is a stream that runs through the wrong
// layer and looks almost right), no carrier ever leaves the die, and the two
// currents do what the lesson says they do - zero current freezes a stream,
// more base current puts more carriers in the sideways one.
const K = require('../kitcheck.js')

const C = K.load(__dirname, 'carriers.js',
    ['defaultDims', 'levels', 'paths', 'arcs', 'pointOn', 'phase', 'shareOf',
     'speedOf', 'carriersAt'])
const A = K.load(__dirname, 'anatomy.js', ['DIE'])

const dims = C.defaultDims()
const L = C.levels(dims)
const half = dims.footprint / 2

function inDie(p) {
    return Math.abs(p.x) <= half + 1e-9 && Math.abs(p.z) <= half + 1e-9
        && p.y >= -1e-9 && p.y <= L.top + 1e-9
}

K.section('the die is anatomy.js\'s die')
K.eq('same footprint', dims.footprint, A.DIE.footprint)
K.eq('same collector thickness', dims.layers.collector, A.DIE.layers.collector.thickness)
K.eq('same base thickness', dims.layers.base, A.DIE.layers.base.thickness)
K.eq('same emitter thickness', dims.layers.emitter, A.DIE.layers.emitter.thickness)
K.eq('same emitter island', dims.emitterFootprint, A.DIE.layers.emitter.footprint)
K.near('the B-C junction is the collector\'s top', L.bc, 0.6)
K.near('the E-B junction is above the base', L.eb, 0.8)
K.near('the die is 1.2 tall', L.top, 1.2)

K.section('paths')
const P = C.paths(dims)
const es = P.filter(p => p.kind === 'e')
const bs = P.filter(p => p.kind === 'b')
K.eq('five emitter paths', es.length, 5)
K.eq('three base paths', bs.length, 3)
K.ok('every path has at least four corners', P.every(p => p.points.length >= 4))
K.ok('every corner is inside the die',
     P.every(p => p.points.every(inDie)),
     JSON.stringify(P.map(p => p.points.filter(q => !inDie(q)))))
K.ok('an emitter path starts on the island\'s top face',
     es.every(p => Math.abs(p.points[0].y - L.top) < 1e-9))
K.ok('an emitter path starts inside the island',
     es.every(p => Math.abs(p.points[0].x) <= dims.emitterFootprint / 2))
K.ok('an emitter path ends inside the collector body',
     es.every(p => { const e = p.points[p.points.length - 1]
                     return e.y > 0 && e.y < L.bc }),
     JSON.stringify(es.map(p => p.points[p.points.length - 1].y)))
K.ok('an emitter path fans outwards',
     es.every(p => Math.abs(p.points[p.points.length - 1].x) >= Math.abs(p.points[0].x)))
K.ok('a base path starts on the +x edge of the die',
     bs.every(p => Math.abs(p.points[0].x - half) < 1e-9),
     JSON.stringify(bs.map(p => p.points[0].x)))
K.ok('a base path stays in the base layer',
     bs.every(p => p.points.every(q => q.y > L.bc && q.y < L.eb)),
     JSON.stringify(bs.map(p => p.points[0].y)))
K.ok('a base path ends in the middle',
     bs.every(p => Math.abs(p.points[p.points.length - 1].x) < 1e-9))

K.section('along a path')
const straight = [{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 0 }, { x: 1, y: 0, z: 3 }]
K.near('arc length adds up', C.arcs(straight).total, 4)
K.near('half way by LENGTH, not by corner', C.pointOn(straight, 0.5).z, 1)
K.near('u 0 is the first corner', C.pointOn(straight, 0).x, 0)
K.near('u 1 is the last corner', C.pointOn(straight, 1).z, 3)
K.near('u clamps below 0', C.pointOn(straight, -2).x, 0)
K.near('u clamps above 1', C.pointOn(straight, 9).z, 3)

K.section('phase is a hash, not a random number')
K.ok('phase is in [0, 1)', [0, 1, 7, 47, 100].every(k => C.phase(k) >= 0 && C.phase(k) < 1))
K.eq('phase repeats for the same k', C.phase(13), C.phase(13))
K.ok('neighbours do not share a phase', C.phase(3) !== C.phase(4))

K.section('the share of base carriers')
K.eq('no base current, no base carriers', C.shareOf(48, 0, 0.8).b, 0)
K.ok('at most half are base carriers', C.shareOf(48, 1, 0).b <= 24,
     'got ' + C.shareOf(48, 1, 0).b)
K.ok('more base current, more base carriers',
     C.shareOf(48, 0.6, 0.8).b > C.shareOf(48, 0.2, 0.8).b,
     C.shareOf(48, 0.6, 0.8).b + ' vs ' + C.shareOf(48, 0.2, 0.8).b)
K.eq('the rest are emitter carriers', C.shareOf(48, 0.3, 0.8).b + C.shareOf(48, 0.3, 0.8).e, 48)

K.section('speed follows the current it belongs to')
K.near('a dead collector current freezes the emitter stream', C.speedOf('e', 1, 0), 0)
K.near('a dead base current freezes the base stream', C.speedOf('b', 0, 1), 0)
K.ok('a driven stream moves', C.speedOf('e', 0, 0.8) > 0)

K.section('carriers')
K.eq('n carriers come back', C.carriersAt(1.3, 0.3, 0.8, 48).length, 48)
K.ok('every carrier is a known kind',
     C.carriersAt(1.3, 0.3, 0.8, 48).every(c => c.kind === 'e' || c.kind === 'b'))
let strays = []
for (const t of [0, 0.017, 0.5, 1, 3.33, 17, 120.75]) {
    for (const iB of [0, 0.3, 1]) {
        for (const iC of [0, 0.5, 0.8, 1]) {
            for (const c of C.carriersAt(t, iB, iC, 48))
                if (!inDie(c)) strays.push({ t, iB, iC, c })
        }
    }
}
K.eq('no carrier ever leaves the die', strays.length, 0, JSON.stringify(strays.slice(0, 3)))

K.section('deterministic in time')
const a1 = C.carriersAt(2.5, 0.3, 0.8, 48)
const a2 = C.carriersAt(2.5, 0.3, 0.8, 48)
K.eq('same t, same array', JSON.stringify(a1), JSON.stringify(a2))
const moved = C.carriersAt(2.51, 0.3, 0.8, 48)
K.ok('a driven stream has moved a hundredth of a second later',
     JSON.stringify(moved) !== JSON.stringify(a1))
const off0 = C.carriersAt(2.5, 0, 0, 48)
const off1 = C.carriersAt(2.51, 0, 0, 48)
K.eq('no current at all is a frozen picture', JSON.stringify(off0), JSON.stringify(off1))
K.ok('a frozen picture is still inside the die', off0.every(inDie))

K.section('the base current is visible in the carriers')
function bCount(iB) { return C.carriersAt(4, iB, 0.8, 48).filter(c => c.kind === 'b').length }
K.eq('no base current, nothing comes in sideways', bCount(0), 0)
K.ok('more base current, more sideways carriers', bCount(1) > bCount(0.3),
     bCount(1) + ' vs ' + bCount(0.3))
K.ok('the base carriers are in the base layer',
     C.carriersAt(4, 0.6, 0.8, 48).filter(c => c.kind === 'b')
        .every(c => c.y > L.bc && c.y < L.eb))

process.exit(K.report('explain kit carriers'))
