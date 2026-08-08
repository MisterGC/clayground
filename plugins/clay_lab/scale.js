// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The measurement half of an instrument: what a reading means on a scale,
// independently of anything that draws it.
//
// An instrument is a model and a face, not a widget. The model says where a
// value sits between two limits, which limits a self-ranging meter picked,
// where the round numbers are, whether the reading is in a good, a warned or
// an alarming part of the scale, and how a real movement lags and holds its
// peak. The face - a needle, a bar, a column, a set of digits - only draws
// that. Every one of those questions is arithmetic, so it lives here in plain
// JS and is checked by `node scale.test.js` with no engine running.
//
// The alternative, which the labs were heading for, is a needle widget, then a
// bar widget that re-derives the same fraction, then a VU widget that gets the
// log mapping subtly wrong. One model times many faces is the difference
// between a foundation and a shelf of lookalikes.
//

// --- self-ranging ----------------------------------------------------------
//
// A bench meter offers a set of full-scale values and selects the smallest one
// the reading still fits in. The needle jumping back to a third of scale as
// the range switches is what a real instrument does, and is a lesson in
// itself, so the rule is kept rather than smoothed away.

function pickRange(value, ranges) {
    if (!ranges || !ranges.length) return 0
    var sorted = ranges.slice().sort(function (a, b) { return a - b })
    var r = Math.abs(Number(value))
    if (!isFinite(r)) r = 0
    for (var i = 0; i < sorted.length; ++i)
        if (r <= sorted[i]) return sorted[i]
    return sorted[sorted.length - 1]
}

// --- position mapping ------------------------------------------------------

// A log scale cannot start at (or below) zero, and a lab that writes min: 0
// with logScale: true means "four decades below the top", not "minus
// infinity". Four is what a VU meter and an audio level display both use.
var LOG_DECADES = 4

function logFloor(lo, hi) {
    var l = Number(lo)
    var h = Math.abs(Number(hi))
    if (!isFinite(h) || h <= 0) h = 1
    if (isFinite(l) && l > 0) return l
    return h / Math.pow(10, LOG_DECADES)
}

// Where `value` sits between the limits, 0 at lo and 1 at hi, clamped. The
// clamp is deliberate: a needle that leaves its face has stopped being a
// measurement, and pinning it at full scale is the honest reading.
function fractionOf(value, lo, hi, logScale) {
    var v = Number(value)
    if (!isFinite(v)) return 0
    if (logScale) {
        var l = logFloor(lo, hi)
        var h = Math.abs(Number(hi))
        if (!(h > l)) return 0
        var a = Math.abs(v)
        if (a <= l) return 0
        if (a >= h) return 1
        return (Math.log(a) - Math.log(l)) / (Math.log(h) - Math.log(l))
    }
    var span = Number(hi) - Number(lo)
    if (!isFinite(span) || span === 0) return 0
    var f = (v - Number(lo)) / span
    return Math.max(0, Math.min(1, f))
}

// The inverse, so a face can put a mark at "40% along" and say what it reads.
function valueAt(fraction, lo, hi, logScale) {
    var f = Math.max(0, Math.min(1, Number(fraction)))
    if (!isFinite(f)) f = 0
    if (logScale) {
        var l = logFloor(lo, hi)
        var h = Math.abs(Number(hi))
        if (!(h > l)) return l
        return l * Math.pow(h / l, f)
    }
    return Number(lo) + f * (Number(hi) - Number(lo))
}

// --- ticks -----------------------------------------------------------------
//
// Heckbert's nice numbers: 1, 2, 5 and their decades. A scale divided into
// arbitrary steps is unreadable even when it is arithmetically correct -
// nobody reads a bar whose gradations are 0.37 apart.

function niceNum(x, round) {
    var a = Math.abs(Number(x))
    if (!isFinite(a) || a === 0) return 0
    var exp = Math.floor(Math.log(a) / Math.LN10)
    var f = a / Math.pow(10, exp)
    var nf
    if (round) {
        if (f < 1.5) nf = 1
        else if (f < 3) nf = 2
        else if (f < 7) nf = 5
        else nf = 10
    } else {
        if (f <= 1) nf = 1
        else if (f <= 2) nf = 2
        else if (f <= 5) nf = 5
        else nf = 10
    }
    return nf * Math.pow(10, exp)
}

// The step a scale of this span wants when it is to carry about `count`
// labelled divisions.
function niceStep(lo, hi, count) {
    var span = Math.abs(Number(hi) - Number(lo))
    var n = Math.max(2, Math.round(Number(count) || 6))
    if (!isFinite(span) || span === 0) return 0
    return niceNum(span / (n - 1), true)
}

// Ticks INSIDE [lo, hi] - the limits are the instrument's, not the tick
// algorithm's, so the range is never quietly widened to a round number the way
// a chart axis may be. A meter that says 0-2 V has to end at 2 V.
//
// Every third-of-a-step in between is a minor tick, which is what makes a
// bar's gradations readable without labelling all of them.
function ticksFor(lo, hi, count, logScale) {
    if (logScale) return logTicks(lo, hi)
    var step = niceStep(lo, hi, count)
    if (!(step > 0)) return []
    var a = Math.min(Number(lo), Number(hi))
    var b = Math.max(Number(lo), Number(hi))
    var eps = step * 1e-6
    var out = []
    // minors sit at half a step; more than that turns a small bar into a comb
    var minor = step / 2
    var first = Math.ceil(a / minor - 1e-9) * minor
    for (var v = first; v <= b + eps; v += minor) {
        var val = Math.abs(v) < eps ? 0 : v
        var isMajor = Math.abs(val / step - Math.round(val / step)) < 1e-6
        out.push({ value: val, major: isMajor })
        if (out.length > 200) break
    }
    return out
}

// Decimals a gradation needs, from the step between gradations. A tick
// labelled "0.50" beside one labelled "1" is two different scales printed on
// one instrument; a tick carrying decimals the step cannot resolve is noise.
//
// Ticks are labelled as bare NUMBERS, not as quantities: an axis whose marks
// read "500 mV, 1.00 V, 1.50 V" changes unit halfway along itself, and the
// unit is already on the face. That was the first thing to go wrong when the
// bar faces landed.
function tickDigits(step) {
    var s = Math.abs(Number(step))
    if (!isFinite(s) || s === 0) return 0
    var e = Math.floor(Math.log(s) / Math.LN10)
    if (e >= 0) return 0
    return Math.min(6, -e)
}

// Decades, plus the 1-2-5 rungs inside them when the span is short enough that
// bare decades would leave a bar with two marks on it.
function logTicks(lo, hi) {
    var l = logFloor(lo, hi)
    var h = Math.abs(Number(hi))
    if (!(h > l)) return []
    var decades = Math.log(h / l) / Math.LN10
    var mantissas = decades <= 2.5 ? [1, 2, 5] : [1]
    var e0 = Math.floor(Math.log(l) / Math.LN10)
    var e1 = Math.ceil(Math.log(h) / Math.LN10)
    var out = []
    for (var e = e0; e <= e1; ++e) {
        for (var i = 0; i < mantissas.length; ++i) {
            var v = mantissas[i] * Math.pow(10, e)
            if (v < l * (1 - 1e-9) || v > h * (1 + 1e-9)) continue
            out.push({ value: v, major: mantissas[i] === 1 })
        }
    }
    return out
}

// --- zones -----------------------------------------------------------------
//
// Three severities, because that is how many an instrument can say without a
// legend: this is fine, this is worth watching, this is wrong. They are named
// rather than coloured here - the colours belong to LabTheme, and a rule that
// hard-codes one stops working the moment the palette flips.

var SEVERITIES = ["ok", "warn", "alarm"]

// The common case written the short way: everything up to okUntil is fine,
// up to warnUntil is warned, the rest alarms. Either bound may be left out
// (NaN/undefined), which simply drops that band.
function zonesFrom(okUntil, warnUntil, lo, hi) {
    var a = Number(okUntil)
    var b = Number(warnUntil)
    var top = Number(hi)
    var out = []
    var at = Number(lo)
    if (isFinite(a)) { out.push({ from: at, to: a, severity: "ok" }); at = a }
    if (isFinite(b) && b > at) { out.push({ from: at, to: b, severity: "warn" }); at = b }
    if (out.length && at < top) out.push({ from: at, to: top, severity: "alarm" })
    return out
}

// The severity a reading falls into. Bands are half-open [from, to) so a value
// landing exactly on a boundary belongs to the calmer band - a reading of
// precisely the alarm threshold is the last good one, not the first bad one.
// With no zones declared an instrument has no opinion, which is "ok".
//
// A reading OFF the end of the scale takes the band at that end, which is not
// a detail: a needle pinned past full scale on an instrument banded red at the
// top read back "ok", because 2.3 V is in no band of a 0-2 V scale. Every face
// pins the reading at the limit; the severity has to pin with it.
function severityAt(value, zones) {
    if (!zones || !zones.length) return "ok"
    var v = Number(value)
    if (!isFinite(v)) return "ok"

    var lo = Infinity
    var hi = -Infinity
    var i, z, from, to
    for (i = 0; i < zones.length; ++i) {
        from = Number(zones[i].from)
        to = Number(zones[i].to)
        if (isFinite(from)) { lo = Math.min(lo, from); hi = Math.max(hi, from) }
        if (isFinite(to)) { lo = Math.min(lo, to); hi = Math.max(hi, to) }
    }
    if (isFinite(lo) && v < lo) v = lo
    if (isFinite(hi) && v > hi) v = hi

    var worst = ""
    for (i = 0; i < zones.length; ++i) {
        z = zones[i]
        from = Number(z.from)
        to = Number(z.to)
        if (!isFinite(from)) from = -Infinity
        if (!isFinite(to)) to = Infinity
        var inside = to > from ? (v >= from && v < to) : (v >= to && v < from)
        // the top band has to include its own end, or full scale reads as
        // having no severity at all
        if (!inside && v === Math.max(from, to)) inside = true
        if (inside && rank(z.severity) > rank(worst)) worst = z.severity
    }
    return worst === "" ? "ok" : worst
}

function rank(sev) {
    var i = SEVERITIES.indexOf(sev)
    return i < 0 ? -1 : i
}

// --- dynamics --------------------------------------------------------------

// A moving-coil movement does not step; it approaches. `damping` is the time
// constant in seconds - the time to close about 63% of the remaining gap -
// and 0 turns the lag off entirely, which is what a digital readout wants.
//
// Exponential rather than a fixed increment because the step has to be
// frame-rate independent: a lab rendering at 30 fps and one at 120 must show
// the same needle at the same sim time.
function lowPass(current, target, damping, dt) {
    var c = Number(current)
    var t = Number(target)
    if (!isFinite(t)) return c
    if (!isFinite(c)) return t
    var tau = Number(damping)
    var d = Number(dt)
    if (!isFinite(tau) || tau <= 0 || !isFinite(d) || d <= 0) return t
    var alpha = 1 - Math.exp(-d / tau)
    return c + (t - c) * alpha
}

// Peak hold, as a level meter does it: the marker jumps to any new maximum at
// once, sits there for `holdTime`, then falls at `fallRate` per second until
// the live reading catches it. State is carried in and out so the whole thing
// stays a pure function - `peak` and `age` are the instrument's memory.
//
// Everything here is in FRACTIONS of the scale, not in the quantity: a fall
// rate in volts would have to be re-tuned for every instrument, and "a third
// of the scale per second" is the same instruction everywhere.
function peakStep(peak, age, current, dt, holdTime, fallRate) {
    var p = Number(peak)
    var a = Number(age)
    var c = Math.max(0, Math.min(1, Number(current)))
    var d = Number(dt)
    if (!isFinite(p)) p = 0
    if (!isFinite(a)) a = 0
    if (!isFinite(c)) c = 0
    if (!isFinite(d) || d < 0) d = 0
    if (c >= p) return { peak: c, age: 0 }
    a += d
    var hold = Number(holdTime)
    if (!isFinite(hold)) hold = 0
    if (a < hold) return { peak: p, age: a }
    var fall = Number(fallRate)
    if (!isFinite(fall) || fall < 0) fall = 0
    return { peak: Math.max(c, p - fall * d), age: a }
}
