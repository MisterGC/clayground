// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The shared harness for kit unit suites.
//
//     const K = require('../kitcheck.js')
//     const C = K.load(__dirname, 'circuit.js', ['solve', 'netsOf'])
//     K.section('solver')
//     K.near('two resistors in series', C.solve(...).i, 0.005, 1e-6)
//     process.exit(K.report('circuit kit'))
//
// A kit's model code is deliberately Qt-free (`.pragma library`, no
// Qt.vector3d, no clock, no randomness of its own) precisely so it can be
// checked here, in a second, with no running engine. That is worth keeping
// cheap: every kit ships a suite, and a suite that needs boilerplate before
// its first assertion tends not to get written - the circuit kit's original
// 19 cases died in a scratch directory for exactly that reason.
//
// Deliberately dependency-free (node's stdlib only) so a kit suite runs
// anywhere node does, including CI images without a package install step.

const fs = require('fs')
const path = require('path')

// Evaluates a kit module into a scope and hands back the named exports.
// The `.pragma library` line is QML's, not node's, so it is stripped.
function load(dir, name, exports) {
    const src = fs.readFileSync(path.join(dir, name), 'utf8')
        .replace(/^\s*\.pragma\s+library\s*$/m, '')
    const fn = new Function(src + '\nreturn {' + exports.join(',') + '}')
    return fn()
}

let pass = 0
let fail = 0
const failures = []

function ok(name, cond, extra) {
    if (cond) { pass++; console.log('  ok   ' + name) }
    else {
        fail++
        failures.push(name)
        console.log('  FAIL ' + name + (extra ? '  <- ' + extra : ''))
    }
}

function eq(name, got, want) {
    ok(name, got === want, 'got ' + got + ', want ' + want)
}

function near(name, got, want, tol) {
    ok(name, Math.abs(got - want) <= (tol === undefined ? 1e-9 : tol),
       'got ' + got + ', want ~' + want)
}

function throws(name, fn) {
    let threw = false
    try { fn() } catch (e) { threw = true }
    ok(name, threw, 'did not throw')
}

function section(s) { console.log('\n' + s) }

// The same generator SimClock uses (mulberry32), so a suite can reproduce a
// run the lab produced: same seed, same stream, same result.
function rngFrom(seed) {
    let a = seed >>> 0
    return function () {
        a = (a + 0x6D2B79F5) | 0
        let t = a
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

// Prints the tally and returns the process exit code, so a failing suite
// fails a build rather than merely printing in red.
function report(what) {
    console.log('\n' + (what || 'suite') + ': ' + pass + ' passed, ' + fail + ' failed')
    if (fail) console.log('failed: ' + failures.join(', '))
    return fail ? 1 : 0
}

module.exports = { load, ok, eq, near, throws, section, rngFrom, report }
