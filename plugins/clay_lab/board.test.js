// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
//     node plugins/clay_lab/board.test.js
//
// The board's rules, with no engine: cell arithmetic, pad rotation, the hit
// test order, keep-out, paths, and serialization. A build lab used to carry
// every one of these inline; now a broken rule fails here rather than in a
// click.

const K = require('../../labs/kits/kitcheck.js')
const B = K.load(__dirname, 'board.js',
    ['JUNCTION', 'DEFAULT', 'specOf', 'cellX', 'cellZ', 'colOf', 'rowOf',
     'terminalCount', 'terminalLocal', 'rotated', 'terminalPos', 'terminalDir',
     'bodyHalf', 'actuatorHalf', 'keepOut', 'aabbHalf', 'inBox',
     'closestOnPath', 'midOfPath', 'straightPath', 'hitAt', 'cellFree',
     'nearestFreeCell', 'newPart', 'withDefaults', 'toState', 'fromState',
     'sameWire', 'obstaclesOf', 'linksOf', 'boundsOf', 'partById'])

const g = { cols: 28, rows: 16, cell: 5 }
const spec = {
    resistor: { terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }], half: { x: 4.6, y: 3.4 },
                actuator: null, fields: { value: 470, on: false }, rows: ["value"] },
    switch:   { terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }], half: { x: 4.6, y: 3.4 },
                actuator: { x: 2.6, y: 2.0 }, fields: { value: 0, on: false }, rows: ["state"] },
    transistor: { terminals: [{ x: -3.5, y: 0 }, { x: 0, y: 3.5 }, { x: 3.5, y: 0 }],
                  half: { x: 4.6, y: 4.6 }, actuator: null, fields: {}, rows: [] },
    gate: { terminals: [{ x: 0, y: -4.6 }, { x: -6, y: -2.6 }, { x: -6, y: 2.6 }, { x: 6, y: 0 }, { x: 0, y: 4.6 }],
            half: { x: 7, y: 5.6 }, actuator: null, fields: { func: "and" }, rows: ["func"] },
    wide: { terminals: [], half: { x: 9, y: 2 }, actuator: null, keepOut: 4, fields: {}, rows: [] }
}

K.section('grid')
K.near('cellX centres the raster', B.cellX(g, (g.cols - 1) / 2), 0, 1e-9)
K.near('cellX of column 0', B.cellX(g, 0), -67.5, 1e-9)
K.near('cellZ of row 0', B.cellZ(g, 0), -37.5, 1e-9)
K.near('colOf inverts cellX', B.colOf(g, B.cellX(g, 7.5)), 7.5, 1e-9)
K.near('rowOf inverts cellZ', B.rowOf(g, B.cellZ(g, 3)), 3, 1e-9)

K.section('spec lookup')
K.ok('unknown type gets the two-pad default', B.specOf(spec, "nothing") === B.DEFAULT)
K.ok('junction is reserved', B.specOf(spec, "junction") === B.JUNCTION)
K.ok('a domain junction overrides the reserved one',
     B.specOf({ junction: { terminals: [], fields: { value: 0 } } }, "junction").fields.value === 0)
K.ok('junction has one terminal at the origin',
     B.terminalCount(spec, "junction") === 1 && B.terminalLocal(spec, "junction", 0).x === 0)
K.ok('terminal counts follow the spec', B.terminalCount(spec, "gate") === 5 && B.terminalCount(spec, "transistor") === 3)
K.near('keepOut derives from the footprint', B.keepOut(spec, g, "resistor"), 4.6 / 5 + 0.7, 1e-9)
K.near('a package reaches further', B.keepOut(spec, g, "gate"), 7 / 5 + 0.7, 1e-9)
K.near('a junction needs only its cell', B.keepOut(spec, g, "junction"), 0.7, 1e-9)
K.ok('an explicit keepOut wins', B.keepOut(spec, g, "wide") === 4)
K.ok('actuator only where declared', B.actuatorHalf(spec, "switch") !== null && B.actuatorHalf(spec, "resistor") === null)

K.section('rotation')
let p = { id: 1, type: "resistor", col: 10, row: 6, rot: 0 }
let t0 = B.terminalPos(spec, g, p, 0), t1 = B.terminalPos(spec, g, p, 1)
K.near('pad 0 sits left of the part', t0.x, B.cellX(g, 10) - 3.5, 1e-9)
K.near('pad 1 sits right of the part', t1.x, B.cellX(g, 10) + 3.5, 1e-9)
p.rot = 90
t0 = B.terminalPos(spec, g, p, 0)
K.near('a quarter turn puts pad 0 on the far side (z)', t0.z, B.cellZ(g, 6) + 3.5, 1e-9)
K.near('...and on the part\'s own x', t0.x, B.cellX(g, 10), 1e-9)
p.rot = 270
t0 = B.terminalPos(spec, g, p, 0)
K.near('three quarter turns put pad 0 at the top', t0.z, B.cellZ(g, 6) - 3.5, 1e-9)
const tr = { id: 2, type: "transistor", col: 4, row: 4, rot: 90 }
const base = B.terminalPos(spec, g, tr, 1)
K.near('an off-axis pad rotates too (x)', base.x, B.cellX(g, 4) + 3.5, 1e-9)
K.near('an off-axis pad rotates too (z)', base.z, B.cellZ(g, 4), 1e-9)

K.section('lead direction')
p.rot = 0
K.ok('pad 0 leaves to -x', JSON.stringify(B.terminalDir(spec, p, 0)) === '{"x":-1,"z":0}')
K.ok('pad 1 leaves to +x', JSON.stringify(B.terminalDir(spec, p, 1)) === '{"x":1,"z":0}')
p.rot = 90
K.ok('turned, pad 0 leaves to +z', JSON.stringify(B.terminalDir(spec, p, 0)) === '{"x":0,"z":1}')
K.ok('a junction has no side', B.terminalDir(spec, { type: "junction", rot: 0 }, 0) === null)
K.ok('the transistor base leaves on the base side', JSON.stringify(B.terminalDir(spec, { type: "transistor", rot: 0 }, 1)) === '{"x":0,"z":1}')

K.section('paths')
const path = [{ x: 0, z: 0 }, { x: 10, z: 0 }, { x: 10, z: 10 }]
let c = B.closestOnPath(path, 5, 1)
K.near('closest point projects onto the first leg', c.x, 5, 1e-9)
K.near('...with the right distance', c.dist, 1, 1e-9)
K.ok('...and the segment index', c.index === 0)
c = B.closestOnPath(path, 12, 8)
K.ok('a corner path finds its second leg', c.index === 1 && Math.abs(c.x - 10) < 1e-9)
K.ok('empty path is infinitely far', B.closestOnPath([], 1, 1).dist === Infinity)
const m = B.midOfPath(path)
K.near('mid by length lands on the corner (x)', m.x, 10, 1e-9)
K.near('mid by length lands on the corner (z)', m.z, 0, 1e-9)
K.ok('straight path is two points', B.straightPath({ x: 1, z: 2 }, { x: 3, z: 4 }).length === 2)

K.section('hit test')
const parts = [
    { id: 1, type: "switch", col: 10, row: 6, rot: 0, value: 0, on: false },
    { id: 2, type: "resistor", col: 16, row: 6, rot: 0, value: 470, on: false },
    { id: 3, type: "junction", col: 13, row: 10, rot: 0 }
]
const wires = [{ id: 4, a: [1, 1], b: [2, 0] }]
const pathOf = (w) => {
    const a = B.terminalPos(spec, g, B.partById(parts, w.a[0]), w.a[1])
    const b = B.terminalPos(spec, g, B.partById(parts, w.b[0]), w.b[1])
    return B.straightPath(a, b)
}
const sx = B.cellX(g, 10), sz = B.cellZ(g, 6)
let h = B.hitAt(spec, g, parts, wires, sx, sz, pathOf)
K.ok('the switch centre is its actuator', h && h.kind === "actuator" && h.el === 1)
h = B.hitAt(spec, g, parts, wires, sx - 3.5, sz, pathOf)
K.ok('its pad is a terminal, not the actuator', h && h.kind === "terminal" && h.ti === 0)
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 16), B.cellZ(g, 6), pathOf)
K.ok('a resistor body is an element', h && h.kind === "element" && h.el === 2)
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 13), B.cellZ(g, 10), pathOf)
K.ok('a junction is hit as a terminal', h && h.kind === "terminal" && h.el === 3)
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 13), B.cellZ(g, 6), pathOf)
K.ok('a wire is grabbed along its path', h && h.kind === "wire" && h.wire === 4)
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 13), B.cellZ(g, 6) + 3, pathOf)
K.ok('nothing three units beside the wire', h === null)
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 16) + 1.0, B.cellZ(g, 6), pathOf)
K.ok('upright, 1 unit along x is the body (the pad is 2.5 away)', h && h.kind === "element")
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 16), B.cellZ(g, 6) + 4.0, pathOf)
K.ok('upright, 4 units along z is outside the body', h === null)
parts[1].rot = 90
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 16) + 3.0, B.cellZ(g, 6), pathOf)
K.ok('turned, 3 units along x is inside the turned extent', h && h.kind === "element")
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 16) + 4.0, B.cellZ(g, 6), pathOf)
K.ok('turned, 4 units along x is outside it', h === null)
h = B.hitAt(spec, g, parts, wires, B.cellX(g, 16), B.cellZ(g, 6) + 4.2, pathOf)
K.ok('turned, the pad moved to z and wins there', h && h.kind === "terminal")
parts[1].rot = 0

K.section('keep-out')
K.ok('a taken cell is not free', !B.cellFree(spec, g, parts, 10, 6, -1, "resistor"))
K.ok('one cell away is still inside the keep-out', !B.cellFree(spec, g, parts, 11, 6, -1, "resistor"))
K.ok('two cells away is free', B.cellFree(spec, g, parts, 12, 6, -1, "resistor"))
K.ok('a part ignores itself', B.cellFree(spec, g, parts, 10, 6, 1, "switch"))
K.ok('a package asks for more room', !B.cellFree(spec, g, parts, 12, 6, -1, "gate") && B.cellFree(spec, g, parts, 13, 6, -1, "gate"))
K.ok('a junction needs one cell', B.cellFree(spec, g, parts, 14, 10, -1, "junction") && !B.cellFree(spec, g, parts, 13, 10, -1, "junction"))
K.ok('...and a part may sit one cell from a junction', B.cellFree(spec, g, parts, 14, 10, -1, "resistor"))
const nf = B.nearestFreeCell(spec, g, parts, 10, 6, "resistor")
K.ok('nearest free cell walks outward', nf !== null && B.cellFree(spec, g, parts, nf.col, nf.row, -1, "resistor"))
K.ok('...row-major within a square: up-left first', JSON.stringify(nf) === '{"col":8,"row":4}')
K.ok('...and returns the asked cell when free', JSON.stringify(B.nearestFreeCell(spec, g, parts, 20, 12, "resistor")) === '{"col":20,"row":12}')
K.ok('...clamped to the board', JSON.stringify(B.nearestFreeCell(spec, g, parts, 99, -3, "resistor")) === '{"col":27,"row":0}')
K.ok('a full board has no free cell', B.nearestFreeCell(spec, { cols: 1, rows: 1, cell: 5 }, [{ id: 9, type: "resistor", col: 0, row: 0 }], 0, 0, "resistor") === null)

K.section('parts and state')
const np = B.newPart(spec, 7, "resistor", 3, 4)
K.ok('a new part carries the spec fields in order',
     JSON.stringify(np) === '{"id":7,"type":"resistor","col":3,"row":4,"rot":0,"value":470,"on":false}')
K.ok('a gate gets its function default', B.newPart(spec, 8, "gate", 0, 0).func === "and")
const st = B.toState(parts, wires, 5)
K.ok('state copies the parts', st.parts.length === 3 && st.parts[0] !== parts[0] && st.parts[0].id === 1)
K.ok('state copies the wires', st.wires[0].a !== wires[0].a && st.wires[0].a[0] === 1)
K.ok('state keeps nextId', st.nextId === 5)
const back = B.fromState(spec, st)
K.ok('round trip keeps every part', JSON.stringify(back.parts) === JSON.stringify(parts))
K.ok('round trip keeps every wire', JSON.stringify(back.wires) === JSON.stringify(wires))
const old = B.fromState(spec, { elements: [{ id: 1, type: "switch", col: 1, row: 1 }], wires: [] })
K.ok('an older payload under "elements" still loads, with defaults', old.parts[0].rot === 0 && old.parts[0].value === 0 && old.parts[0].on === false)
K.ok('a payload without nextId derives one', old.nextId === 2)
K.ok('sameWire is direction-blind', B.sameWire({ a: [1, 0], b: [2, 1] }, [2, 1], [1, 0]) && !B.sameWire({ a: [1, 0], b: [2, 1] }, [1, 1], [2, 1]))

K.section('for routers and cameras')
const obs = B.obstaclesOf(spec, g, parts)
K.ok('junctions are not obstacles', obs.length === 2 && obs.every(o => o.id !== 3))
K.near('an obstacle carries its half-extent', obs[0].hx, 4.6, 1e-9)
const links = B.linksOf(spec, g, parts, wires)
K.ok('a link carries both ends and their sides', links.length === 1 && links[0].a.dir.x === 1 && links[0].b.dir.x === -1 && links[0].ends[1] === 2)
K.ok('a wire to a missing part is dropped', B.linksOf(spec, g, parts, [{ id: 9, a: [1, 0], b: [99, 0] }]).length === 0)
const bb = B.boundsOf(g, parts.slice(0, 1), 7)
K.ok('bounds pad each part by the given extent', bb.length === 2 && Math.abs((bb[1].x - bb[0].x) - 14) < 1e-9)

process.exit(K.report('board'))
