// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The quantity layer: a number, a unit, and the SI prefix that makes it
// readable.
//
// Every lab so far hand-rolled its own crossover - electronics wrote
//
//     Math.abs(i) >= 0.9995 ? num(i, 2) + " A" : num(i * 1000, 1) + " mA"
//
// once for amps and again, differently, for volts; sensor-fusion did metres
// and seconds its own way; the circuit kit's meter ranges did it a third time.
// Three implementations of one rule is the definition of something that
// belongs in the kernel, and the rule has enough edges (the 0.9995 rounding
// boundary, a unit that must NOT take a prefix, a value of exactly zero) that
// the fourth copy would have been the one with the bug.
//
// Pure JS so `node format.test.js` checks it: the decimal separator arrives as
// an argument rather than being read off LabLang, which is what keeps this
// file engine-free. LabLang.qty() is the two-line binding that supplies it.
//

// Prefixes from pico to giga, largest first. Deliberately stops at G: a lab
// quantity beyond that is a modelling mistake, not a formatting problem.
var PREFIXES = [
    { p: 1e9, s: "G" },
    { p: 1e6, s: "M" },
    { p: 1e3, s: "k" },
    { p: 1, s: "" },
    { p: 1e-3, s: "m" },
    { p: 1e-6, s: "µ" },
    { p: 1e-9, s: "n" },
    { p: 1e-12, s: "p" }
]

// Units that carry an SI prefix. Anything else - a percentage, a rate like
// "/min" or "u/s", a count, a bare "" - is printed as it stands, because
// "mu/s" means nothing and "k%" means less.
//
// Ohm is listed in both spellings; a lab may write either.
var PREFIXABLE = ["A", "V", "W", "s", "m", "g", "Hz", "F", "H", "J", "N",
                  "\u03a9", "\u2126", "Wh", "B", "bit", "Pa", "C", "S"]

function takesPrefix(unit) {
    if (!unit) return false
    for (var i = 0; i < PREFIXABLE.length; ++i)
        if (PREFIXABLE[i] === unit) return true
    return false
}

// Digits for a magnitude when the caller did not say: three significant
// figures, which is what an instrument reading is worth and what every
// hand-rolled version happened to converge on.
function autoDigits(scaled) {
    var a = Math.abs(scaled)
    if (a >= 100) return 0
    if (a >= 10) return 1
    return 2
}

// The prefix a value should wear: the largest one that still leaves the
// magnitude at or above 1, so 0.05 A becomes 50 mA and 1500 A becomes 1.5 kA.
//
// The comparison is made against the ROUNDED value, not the raw one: 0.9996 A
// with two digits prints as "1.00", and choosing milli for it would have shown
// "999.60 mA" beside a needle that has visibly reached the end of its scale.
function prefixFor(value, digits) {
    var a = Math.abs(Number(value))
    if (!isFinite(a) || a === 0) return PREFIXES[3]      // the empty prefix
    for (var i = 0; i < PREFIXES.length; ++i) {
        var scaled = a / PREFIXES[i].p
        var d = digits === undefined ? autoDigits(scaled) : digits
        if (Number(scaled.toFixed(d)) >= 1) return PREFIXES[i]
    }
    return PREFIXES[PREFIXES.length - 1]
}

// The core: value + unit, prefixed, with `sep` as the decimal separator.
//
// Returns the pieces as well as the finished string, because a gauge wants to
// print the number large and the unit small, and re-splitting a formatted
// string to get there is how a formatter ends up with two callers and three
// behaviours.
function parts(value, unit, digits, sep) {
    var v = Number(value)
    if (!isFinite(v)) v = 0
    var pfx = takesPrefix(unit) ? prefixFor(v, digits) : PREFIXES[3]
    var scaled = v / pfx.p
    var d = digits === undefined ? autoDigits(scaled) : digits
    var num = scaled.toFixed(d)
    // -0.00 is a rounding artefact, never a reading
    if (Number(num) === 0) num = (0).toFixed(d)
    if (sep && sep !== ".") num = num.replace(".", sep)
    return { number: num, prefix: pfx.s, unit: unit ? unit : "",
             fullUnit: (pfx.s + (unit ? unit : "")) }
}

// "50.0 mA" / "50,0 mA". The unit is separated by a normal space; a lab that
// wants a thin space can build it from parts().
function qty(value, unit, digits, sep) {
    var p = parts(value, unit, digits, sep)
    return p.fullUnit === "" ? p.number : p.number + " " + p.fullUnit
}

// --- statistics ------------------------------------------------------------
//
// Welford's online algorithm rather than the sum-of-squares shortcut: over a
// probe's 1200 retained samples of something like a 9.81 baseline with
// millimetre noise, the naive form cancels the mean out of a much larger sum
// and can return a negative variance. This one never does.

function stats(values) {
    var n = 0, mean = 0, m2 = 0
    for (var i = 0; i < values.length; ++i) {
        var x = Number(values[i])
        if (!isFinite(x)) continue
        n += 1
        var delta = x - mean
        mean += delta / n
        m2 += delta * (x - mean)
    }
    if (n === 0) return { count: 0, mean: 0, variance: 0, stddev: 0 }
    // population variance: a probe series is the whole run, not a sample of it
    var variance = m2 / n
    if (variance < 0) variance = 0
    return { count: n, mean: mean, variance: variance,
             stddev: Math.sqrt(variance) }
}
