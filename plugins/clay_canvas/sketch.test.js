// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_canvas/sketch.test.js
//
// The pen's geometry and the ink split, with no engine: the look table, the
// noise a hand adds to a sample, the resampling of a polyline, arrow heads,
// how one progress number is shared out over parts, and where a ray leaves a
// box. A wrong rule fails here rather than in a screenshot nobody compares.

const K = require('../../labs/kits/kitcheck.js')
const S = K.load(__dirname, 'sketch.js',
    ['LOOKS', 'STEP', 'HEAD_ANGLE', 'GLYPH_INK', 'look', 'isSketch', 'hash',
     'smooth', 'offset', 'dist', 'polyLength', 'pieces', 'sample', 'displaced',
     'arrowHead', 'split', 'glyphs', 'textInk', 'boxEdge'])

K.section('constants')
K.eq('three looks', S.LOOKS.length, 3)
K.ok('LOOKS names the looks', S.LOOKS.join(',') === 'none,chalk,marker')
K.eq('sample spacing', S.STEP, 14)
K.near('head angle', S.HEAD_ANGLE, 0.46)
K.near('glyph ink', S.GLYPH_INK, 0.6)

K.section('look')
const chalk = S.look('chalk')
const marker = S.look('marker')
const none = S.look('none')
K.eq('chalk keeps its name', chalk.name, 'chalk')
K.near('chalk wobbles', chalk.wobble, 0.35)
K.near('chalk is jagged', chalk.jag, 0.30)
K.near('chalk is not fully opaque', chalk.alpha, 0.92)
K.ok('chalk has grain', chalk.grain === true)
K.near('chalk grain alpha', chalk.grainAlpha, 0.22)
K.near('chalk grain width', chalk.grainWidth, 1.8)
K.eq('marker keeps its name', marker.name, 'marker')
K.near('marker wobbles slowly', marker.wobble, 0.30)
K.near('marker is nearly smooth', marker.jag, 0.05)
K.near('marker is opaque', marker.alpha, 1.0)
K.ok('marker has no grain', marker.grain === false)
K.eq('none is the plain pen', none.name, 'none')
K.ok('none does not move a thing', none.wobble === 0 && none.jag === 0)
K.eq('an unknown name falls back', S.look('crayon').name, 'none')
K.eq('undefined falls back', S.look(undefined).name, 'none')
K.eq('a property name is not a look', S.look('constructor').name, 'none')
K.ok('the table is not shared', S.look('chalk') !== S.look('chalk'))
K.ok('isSketch knows the two sketch looks', S.isSketch('chalk') && S.isSketch('marker'))
K.ok('isSketch rejects the rest',
     !S.isSketch('none') && !S.isSketch('crayon') && !S.isSketch(undefined))

K.section('hash')
K.eq('the same input twice', S.hash(17, 3), S.hash(17, 3))
K.ok('a different seed is a different stream', S.hash(17, 3) !== S.hash(17, 4))
K.ok('neighbouring samples differ', S.hash(17, 3) !== S.hash(18, 3))
let hashInRange = true, hashSpread = 0
for (let k = -200; k <= 1000; ++k) {
    const h = S.hash(k, 11)
    if (!(h >= -1 && h < 1) || !isFinite(h)) hashInRange = false
    if (h > 0) hashSpread++
}
K.ok('hash stays in [-1, 1)', hashInRange)
K.ok('hash uses both halves of the range', hashSpread > 400 && hashSpread < 800)

K.section('smooth')
K.eq('smooth is deterministic', S.smooth(9, 2), S.smooth(9, 2))
K.ok('a different seed is a different drift', S.smooth(9, 2) !== S.smooth(9, 5))
K.near('a lattice sample is its hashed value', S.smooth(8, 2), S.hash(2, 2))
K.near('the next lattice point', S.smooth(12, 2), S.hash(3, 2))
K.near('halfway is the midpoint', S.smooth(10, 2), (S.hash(2, 2) + S.hash(3, 2)) / 2)
let smoothInRange = true, maxJump = 0, prev = S.smooth(0, 2)
for (let k = 1; k <= 500; ++k) {
    const v = S.smooth(k, 2)
    if (!(v >= -1 && v <= 1)) smoothInRange = false
    maxJump = Math.max(maxJump, Math.abs(v - prev))
    prev = v
}
K.ok('smooth stays in [-1, 1]', smoothInRange)
K.ok('smooth drifts, it does not jump', maxJump < 1.0, 'max step ' + maxJump)

K.section('offset')
K.eq('offset is deterministic', S.offset(4, 1, chalk), S.offset(4, 1, chalk))
K.eq('offset takes a look by name', S.offset(4, 1, 'chalk'), S.offset(4, 1, chalk))
K.eq('none never moves a sample', S.offset(4, 1, none), 0)
K.eq('an unknown look never moves a sample', S.offset(4, 1, 'crayon'), 0)
K.ok('a different seed is a different hand', S.offset(4, 1, chalk) !== S.offset(4, 2, chalk))
let chalkMax = 0, markerMax = 0
for (let k = 0; k <= 500; ++k) {
    chalkMax = Math.max(chalkMax, Math.abs(S.offset(k, 13, chalk)))
    markerMax = Math.max(markerMax, Math.abs(S.offset(k, 13, marker)))
}
K.ok('chalk stays within wobble + jag', chalkMax <= chalk.wobble + chalk.jag, 'max ' + chalkMax)
K.ok('marker stays within wobble + jag', markerMax <= marker.wobble + marker.jag, 'max ' + markerMax)
K.ok('chalk is rougher than marker', chalkMax > markerMax)

K.section('dist and polyLength')
K.near('a 3-4-5 hypotenuse', S.dist({ x: 0, y: 0 }, { x: 3, y: 4 }), 5)
K.eq('no points cost nothing', S.polyLength([]), 0)
K.eq('one point costs nothing', S.polyLength([{ x: 1, y: 2 }]), 0)
K.near('two sides of a 3-4-5 triangle',
       S.polyLength([{ x: 0, y: 0 }, { x: 0, y: 4 }, { x: 3, y: 0 }]), 9)
K.eq('a missing list costs nothing', S.polyLength(undefined), 0)

K.section('pieces')
K.eq('a zero-length segment is still one piece', S.pieces(0, 14), 1)
K.eq('exactly one step is one piece', S.pieces(14, 14), 1)
K.eq('a hair over a step is two', S.pieces(14.0001, 14), 2)
K.eq('a hundred at fourteen', S.pieces(100, 14), 8)
K.eq('a step of zero is one piece', S.pieces(100, 0), 1)
K.eq('a negative step is one piece', S.pieces(100, -3), 1)

K.section('sample')
const line = S.sample([{ x: 0, y: 0 }, { x: 100, y: 0 }], 14)
K.eq('one vertex plus eight pieces', line.length, 9)
K.ok('the first sample is the first vertex',
     line[0].x === 0 && line[0].y === 0 && line[0].vertex === true)
K.ok('the last sample is the last vertex',
     line[8].x === 100 && line[8].y === 0 && line[8].vertex === true)
let onLine = true, monotone = true, normalsRight = true
for (let i = 0; i < line.length; ++i) {
    if (line[i].y !== 0) onLine = false
    if (i > 0 && !(line[i].x > line[i - 1].x)) monotone = false
    if (line[i].nx !== 0 || line[i].ny !== 1) normalsRight = false
    if (i > 0 && i < line.length - 1 && line[i].vertex !== false) onLine = false
}
K.ok('every sample lies on the line', onLine)
K.ok('the samples advance', monotone)
K.ok('the left normal of a +x segment is (0, 1)', normalsRight)
K.near('the samples are evenly spaced', line[1].x, 12.5)

const up = S.sample([{ x: 0, y: 0 }, { x: 0, y: 10 }], 4)
K.near('the left normal of a +y segment is (-1, 0)', up[1].nx, -1)
K.near('and has no y part', up[1].ny, 0)

const corner = S.sample([{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }], 5)
K.eq('a corner is sampled per segment', corner.length, 5)
K.ok('a vertex carries its outgoing normal', corner[0].ny === 1 && corner[2].nx === -1)
K.ok('the last vertex carries the incoming one', corner[4].nx === -1 && corner[4].vertex === true)

const dup = S.sample([{ x: 0, y: 0 }, { x: 0, y: 0 }, { x: 10, y: 0 }], 5)
K.eq('a zero-length segment adds no interior point', dup.length, 4)
K.ok('a repeated vertex is still a vertex', dup[0].vertex === true && dup[1].vertex === true)
K.ok('and it does not produce NaN', isFinite(dup[1].nx) && isFinite(dup[1].ny))

K.eq('empty input comes back empty', S.sample([], 14).length, 0)
K.eq('missing input comes back empty', S.sample(undefined, 14).length, 0)
const one = S.sample([{ x: 3, y: 4 }], 14)
K.eq('one point comes back as one sample', one.length, 1)
K.ok('with no normal', one[0].nx === 0 && one[0].ny === 0 && one[0].vertex === true)
K.eq('a step of zero leaves the vertices alone', S.sample([{ x: 0, y: 0 }, { x: 100, y: 0 }], 0).length, 2)

K.section('displaced')
const sw = 3
const vtx = S.displaced(line[0], 0, 5, chalk, sw)
K.ok('a vertex is never moved', vtx.x === line[0].x && vtx.y === line[0].y)
const endv = S.displaced(line[8], 8, 5, chalk, sw)
K.ok('nor is the last vertex', endv.x === 100 && endv.y === 0)
const mid = S.displaced(line[3], 3, 5, chalk, sw)
const o3 = S.offset(3, 5, chalk) * sw
K.near('an interior sample keeps its x on a +x segment', mid.x, line[3].x)
K.near('and moves along the normal', mid.y, line[3].y + o3)
K.near('by |offset * strokeWidth|', Math.abs(mid.y - line[3].y), Math.abs(o3))
const plain = S.displaced(line[3], 3, 5, none, sw)
K.ok('the plain pen leaves a sample where it was',
     plain.x === line[3].x && plain.y === line[3].y)

K.section('arrowHead')
const h = S.arrowHead({ x: 0, y: 0 }, { x: 10, y: 0 }, 4)
K.ok('the tip is the end point', h.tip.x === 10 && h.tip.y === 0)
K.near('the left barb is size away', S.dist(h.left, h.tip), 4)
K.near('the right barb is size away', S.dist(h.right, h.tip), 4)
K.ok('the barbs differ', h.left.x !== h.right.x || h.left.y !== h.right.y)
const back = Math.atan2(0 - 0, 0 - 10)
// atan2 wraps at pi, and the back direction of a +x shaft sits exactly there,
// so the barb angles are compared as a wrapped difference.
const offBy = (b) => {
    let d = Math.atan2(b.y - h.tip.y, b.x - h.tip.x) - back
    while (d > Math.PI) d -= 2 * Math.PI
    while (d < -Math.PI) d += 2 * Math.PI
    return d
}
K.near('the left barb sits HEAD_ANGLE off the shaft', offBy(h.left), S.HEAD_ANGLE, 1e-9)
K.near('the right barb sits HEAD_ANGLE the other way', offBy(h.right), -S.HEAD_ANGLE, 1e-9)
K.near('the barbs are symmetric about the shaft', offBy(h.left) + offBy(h.right), 0, 1e-9)
K.ok('the barbs point back along the shaft', h.left.x < 10 && h.right.x < 10)
const hd = S.arrowHead({ x: 0, y: 0 }, { x: 3, y: 4 }, 5)
K.near('a diagonal head keeps its barb distance', S.dist(hd.left, hd.tip), 5)
const deg = S.arrowHead({ x: 2, y: 2 }, { x: 2, y: 2 }, 6)
K.ok('a zero-length shaft puts the barbs on the tip',
     deg.left.x === 2 && deg.left.y === 2 && deg.right.x === 2 && deg.right.y === 2)
K.ok('and produces no NaN', isFinite(deg.left.x) && isFinite(deg.right.y))

K.section('split')
const eqArr = (name, got, want) => K.ok(name, got.length === want.length &&
    got.every((v, i) => Math.abs(v - want[i]) <= 1e-9), 'got [' + got + ']')
eqArr('half of two equal parts', S.split([1, 1], 0.5), [1, 0])
eqArr('a quarter is half the first part', S.split([1, 1], 0.25), [0.5, 0])
eqArr('three quarters', S.split([1, 1], 0.75), [1, 0.5])
eqArr('all of it', S.split([1, 1], 1), [1, 1])
eqArr('none of it', S.split([1, 1], 0), [0, 0])
eqArr('over one clamps', S.split([1, 1], 2), [1, 1])
eqArr('under zero clamps', S.split([1, 1], -1), [0, 0])
eqArr('a non-number draws nothing', S.split([1, 1], 'half'), [0, 0])
eqArr('undefined draws nothing', S.split([1, 1], undefined), [0, 0])
eqArr('NaN draws nothing', S.split([1, 1], NaN), [0, 0])
eqArr('a dearer part takes longer', S.split([3, 1], 0.5), [2 / 3, 0])
eqArr('and the cheap one finishes fast', S.split([3, 1], 0.875), [1, 0.5])
eqArr('a free part before the cursor is done', S.split([1, 0, 1], 0.75), [1, 1, 0.5])
eqArr('a free part after the cursor is not', S.split([1, 0, 1], 0.25), [0.5, 0, 0])
eqArr('a free part at the cursor is done, never in progress', S.split([1, 0, 1], 0.5), [1, 1, 0])
eqArr('a free last part is done at progress 1', S.split([1, 0], 1), [1, 1])
eqArr('a free first part is not done at progress 0', S.split([0, 1], 0), [0, 0])
eqArr('all free parts, started', S.split([0, 0], 0.5), [1, 1])
eqArr('all free parts, not started', S.split([0, 0], 0), [0, 0])
eqArr('a negative price is a free part', S.split([-1, 1], 1), [1, 1])
K.eq('no parts, no fractions', S.split([], 0.5).length, 0)
K.eq('a missing list gives no fractions', S.split(undefined, 0.5).length, 0)
let splitSane = true
for (let i = 0; i <= 20; ++i) {
    const f = S.split([2, 0, 5, 1], i / 20)
    for (let j = 0; j < f.length; ++j)
        if (!isFinite(f[j]) || f[j] < 0 || f[j] > 1) splitSane = false
}
K.ok('every fraction stays in [0, 1]', splitSane)

K.section('glyphs')
K.eq('nothing shown at zero', S.glyphs('hello', 0), 0)
K.eq('halfway rounds up to a whole character', S.glyphs('hello', 0.5), 3)
K.eq('all of it at one', S.glyphs('hello', 1), 5)
K.eq('over one clamps', S.glyphs('hello', 2), 5)
K.eq('under zero clamps', S.glyphs('hello', -1), 0)
K.eq('empty text has no characters', S.glyphs('', 0.5), 0)
K.eq('missing text has no characters', S.glyphs(undefined, 0.5), 0)
K.eq('a non-number shows nothing', S.glyphs('hello', 'half'), 0)

K.section('textInk')
K.near('three glyphs at size ten', S.textInk('abc', 10), 18)
K.eq('empty text is free', S.textInk('', 10), 0)
K.eq('missing text is free', S.textInk(undefined, 10), 0)
K.near('twice the text, twice the ink', S.textInk('abcabc', 10), 2 * S.textInk('abc', 10))

K.section('boxEdge')
const e = (tx, ty) => S.boxEdge(10, 20, 4, 2, tx, ty)
let r = e(100, 20)
K.ok('straight right leaves at the right side', r.x === 14 && r.y === 20)
r = e(-100, 20)
K.ok('straight left leaves at the left side', r.x === 6 && r.y === 20)
r = e(10, 100)
K.ok('straight up leaves at the top side', r.x === 10 && r.y === 22)
r = e(10, -100)
K.ok('straight down leaves at the bottom side', r.x === 10 && r.y === 18)
r = S.boxEdge(0, 0, 5, 5, 100, 100)
K.ok('45 degrees on a square is the corner', r.x === 5 && r.y === 5)
r = S.boxEdge(0, 0, 5, 5, -100, 100)
K.ok('the other corner too', r.x === -5 && r.y === 5)
r = e(11, 21)
K.ok('a target inside is the centre', r.x === 10 && r.y === 20)
r = e(10, 20)
K.ok('the centre itself is the centre', r.x === 10 && r.y === 20)
r = e(14, 22)
K.ok('a target on the corner counts as inside', r.x === 10 && r.y === 20)
r = S.boxEdge(10, 20, 0, 2, 100, 20)
K.ok('a box with no width is the centre', r.x === 10 && r.y === 20)
r = S.boxEdge(10, 20, 4, 0, 10, 100)
K.ok('a box with no height is the centre', r.x === 10 && r.y === 20)
r = S.boxEdge(10, 20, -4, 2, 100, 20)
K.ok('a negative half size is the centre', r.x === 10 && r.y === 20)
r = e(NaN, 20)
K.ok('a NaN target is the centre', r.x === 10 && r.y === 20)
let edgeOnBox = true
for (let a = 0; a < 2 * Math.PI; a += Math.PI / 37) {
    const p = S.boxEdge(0, 0, 3, 7, 1000 * Math.cos(a), 1000 * Math.sin(a))
    const onEdge = Math.abs(Math.abs(p.x) - 3) < 1e-9 || Math.abs(Math.abs(p.y) - 7) < 1e-9
    if (!onEdge || Math.abs(p.x) > 3 + 1e-9 || Math.abs(p.y) > 7 + 1e-9) edgeOnBox = false
}
K.ok('every direction leaves on the box', edgeOnBox)

process.exit(K.report('canvas sketch'))
