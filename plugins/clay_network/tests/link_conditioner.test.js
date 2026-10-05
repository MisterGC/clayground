// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The browser's link conditioner (#301) on a test clock - the same cases
// tst_link_conditioner.cpp checks for the native one, so the two backends
// simulate the same link.
//
//     node plugins/clay_network/tests/link_conditioner.test.js
const assert = require('assert')
const path = require('path')
const LC = require(path.join(__dirname, '..', 'link_conditioner.js'))

let t = 0
let randoms = []
let nextRandom = 0

function make() {
    return LC.create({
        now: () => t,
        random: () => randoms.length ? randoms[nextRandom++ % randoms.length] : 0.5,
    })
}
function advance(c, toMs) { t = toMs; c.pump(t) }

const cases = []
function test(name, fn) { cases.push({ name, fn }) }

test('clean link delivers inside offer', () => {
    const c = make()
    assert.strictEqual(c.active(), false)
    let got = 0
    c.offer('out', true, 100, () => ++got)
    c.offer('in', false, 100, () => ++got)
    assert.strictEqual(got, 2)
})

test('conditions are clamped', () => {
    const c = make()
    c.setConditions({ loss: 3, latencyMs: -5, jitterMs: 10, bandwidthKbps: -1, blackout: true, bogus: 1 })
    assert.deepStrictEqual(c.conditions(), {
        loss: 1, latencyMs: 0, jitterMs: 10, bandwidthKbps: 0, blackout: true, dropSignaling: false,
    })
})

test('latency delays every packet', () => {
    const c = make()
    c.setConditions({ latencyMs: 80 })
    const at = []
    c.offer('out', true, 10, () => at.push(t))
    c.offer('in', false, 10, () => at.push(t))
    advance(c, 1079)
    assert.deepStrictEqual(at, [])
    advance(c, 1080)
    assert.deepStrictEqual(at, [1080, 1080])
})

test('loss drops state only', () => {
    const c = make()
    randoms = [0.05, 0.5, 0.6, 0.7, 0.8, 0.9, 0.2, 0.3, 0.4, 0.95]
    c.setConditions({ loss: 0.1 })
    let state = 0, reliable = 0
    for (let i = 0; i < 1000; ++i) {
        c.offer('out', true, 10, () => ++state)
        c.offer('out', false, 10, () => ++reliable)
    }
    advance(c, 1001)
    assert.strictEqual(state, 900)
    assert.strictEqual(reliable, 1000)
    assert.strictEqual(c.stats.dropped, 100)
})

test('total loss never touches reliable', () => {
    const c = make()
    c.setConditions({ loss: 1 })
    let state = 0, reliable = 0
    for (let i = 0; i < 50; ++i) {
        c.offer('in', true, 10, () => ++state)
        c.offer('in', false, 10, () => ++reliable)
    }
    advance(c, 1001)
    assert.strictEqual(state, 0)
    assert.strictEqual(reliable, 50)
})

test('jitter reorders state but not reliable', () => {
    const c = make()
    randoms = [0.99, 0.5, 0.0]
    c.setConditions({ latencyMs: 50, jitterMs: 100 })
    const state = [], reliable = []
    for (let i = 0; i < 3; ++i) c.offer('out', true, 10, () => state.push(i))
    nextRandom = 0
    for (let i = 0; i < 3; ++i) c.offer('out', false, 10, () => reliable.push(i))
    advance(c, 1200)
    assert.deepStrictEqual(state, [2, 1, 0])
    assert.deepStrictEqual(reliable, [0, 1, 2])
})

test('jitter stays within bounds', () => {
    const c = make()
    randoms = [0.0, 0.999999]
    c.setConditions({ latencyMs: 100, jitterMs: 20 })
    const at = []
    c.offer('out', true, 10, () => at.push(t))
    c.offer('out', true, 10, () => at.push(t))
    for (let ms = 1000; ms <= 1200; ++ms) advance(c, ms)
    assert.deepStrictEqual(at, [1100, 1120])
})

test('bandwidth spaces packets per direction', () => {
    const c = make()
    c.setConditions({ bandwidthKbps: 80, latencyMs: 10 })
    const out = [], inn = []
    for (let i = 0; i < 3; ++i) {
        c.offer('out', i % 2 === 0, 1000, () => out.push(t))
        // a size given as a function is only asked for under a cap
        c.offer('in', false, () => 1000, () => inn.push(t))
    }
    for (let ms = 1000; ms <= 1400; ++ms) advance(c, ms)
    assert.deepStrictEqual(out, [1110, 1210, 1310])
    assert.deepStrictEqual(inn, [1110, 1210, 1310])
})

test('blackout drops state and holds reliable', () => {
    const c = make()
    c.setConditions({ latencyMs: 20, blackout: true })
    const reliable = []
    let state = 0
    for (let i = 0; i < 5; ++i) {
        c.offer('out', true, 10, () => ++state)
        c.offer('out', false, 10, () => reliable.push(i))
    }
    advance(c, 3000)
    assert.strictEqual(state, 0)
    assert.deepStrictEqual(reliable, [])
    assert.strictEqual(c.stats.held, 5)
    assert.strictEqual(c.stats.dropped, 5)

    c.setConditions({ latencyMs: 20 })
    c.offer('out', false, 10, () => reliable.push(5))
    advance(c, 3019)
    assert.deepStrictEqual(reliable, [])
    advance(c, 3020)
    assert.deepStrictEqual(reliable, [0, 1, 2, 3, 4, 5])
})

test('reliable keeps order when conditions clear', () => {
    const c = make()
    c.setConditions({ latencyMs: 100 })
    const got = []
    c.offer('in', false, 10, () => got.push(0))
    c.setConditions({})
    c.offer('in', false, 10, () => got.push(1))
    assert.deepStrictEqual(got, [])
    advance(c, 1100)
    assert.deepStrictEqual(got, [0, 1])
    c.offer('in', false, 10, () => got.push(2))
    assert.deepStrictEqual(got, [0, 1, 2])
})

test('delivery may offer again', () => {
    const c = make()
    c.setConditions({ latencyMs: 30 })
    const at = []
    c.offer('in', false, 10, () => {
        at.push(t)
        c.offer('out', false, 10, () => at.push(t))
    })
    advance(c, 1030)
    advance(c, 1060)
    assert.deepStrictEqual(at, [1030, 1060])
})

test('clear forgets everything', () => {
    const c = make()
    c.setConditions({ latencyMs: 30 })
    let got = 0
    c.offer('out', false, 10, () => ++got)
    c.setConditions({ blackout: true })
    c.offer('out', false, 10, () => ++got)
    c.clear()
    c.setConditions({})
    advance(c, 5000)
    assert.strictEqual(got, 0)
})

test('dropSignaling is reported', () => {
    const c = make()
    assert.strictEqual(c.dropSignaling(), false)
    c.setConditions({ dropSignaling: true })
    assert.strictEqual(c.dropSignaling(), true)
    // it conditions no data channel traffic by itself
    assert.strictEqual(c.active(), false)
})

let failed = 0
for (const k of cases) {
    t = 1000; randoms = []; nextRandom = 0
    try {
        k.fn()
        console.log('PASS  ' + k.name)
    } catch (e) {
        failed++
        console.log('FAIL  ' + k.name + '\n      ' + e.message.split('\n').join('\n      '))
    }
}

// The real timer, not the test clock: a delayed packet arrives on its own
const real = LC.create()
real.setConditions({ latencyMs: 40 })
const start = Date.now()
real.offer('out', true, 10, () => {
    const took = Date.now() - start
    const ok = took >= 39
    if (!ok) failed++
    console.log((ok ? 'PASS  ' : 'FAIL  ') + 'real timer delivers (' + took + ' ms)')
    console.log(`\n${cases.length + 1 - failed}/${cases.length + 1} passed`)
    process.exit(failed ? 1 : 0)
})
setTimeout(() => {
    console.log('FAIL  real timer delivers (never)')
    process.exit(1)
}, 2000)
