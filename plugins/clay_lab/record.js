// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

//
// The run record: one self-describing, diffable text file per run (#203).
//
// A record is what a paper cites. That single sentence decides everything
// below: it must be readable by a person opening it cold, parseable by a tool
// without a schema on the side, byte-identical for two runs of the same seed
// (so "is this still true?" is a `diff`, not an argument), and small enough to
// live in git beside the lab that produced it.
//
// SHAPE - why a JSON header and a tab-separated table rather than one format
// for both. The two halves of a record have genuinely different shapes: the
// provenance (lab, scenario, seed, parameters, per-probe summaries) is a small
// nested heterogeneous thing, which is what JSON is for; the samples are a
// large homogeneous rectangle, which is what a table is for. Forcing the
// rectangle into JSON gives a file whose every line carries brackets and
// quotes and whose diffs are unreadable; forcing the header into CSV loses the
// nesting. So each half gets the serialization that fits it, in one file, with
// a marker line between them:
//
//     # Clayground lab record v1 ...
//     { ...json header... }
//     # samples
//     t<TAB>errFused<TAB>errGps
//     0<TAB>0.0231<TAB>
//
// The JSON is emitted by hand rather than by JSON.stringify so that the LINE
// GRANULARITY is controlled: one line per parameter, one line per probe
// summary. A changed parameter is then a one-line diff, and a probe whose
// statistics moved is one line - which is the whole point of a diffable
// record. It is still valid JSON, so parse() is JSON.parse over that block.
//
// NO WALL CLOCK. There is deliberately no "generated at" field. A timestamp
// would make every re-run differ, which would destroy the one property that
// makes a record worth committing: two runs of the same seed and scenario
// produce the same bytes. Dates belong in the file NAME (and hence in the id,
// which is an INPUT to the run), never in its content.
//
// NUMBERS are rounded to a fixed number of significant figures before
// printing. Full double precision would be honest but noisy - a paper quotes
// six figures at most, and the last three digits of a float turn a meaningful
// diff into a wall of churn. The rounding is deterministic (toPrecision is
// spec-defined), so byte-comparison still works.
//
// EMPTY CELLS are meaningful: a probe only records finite values, so a run
// where GPS had no fix at t=3.2 has a blank there rather than a repeat of the
// last reading. Carrying a stale value forward would invent a measurement.
//
// Pure JS (no Qt types) so `node record.test.js` checks all of it with no
// engine - the same contract every kit model obeys.
//

var FORMAT = "clay-lab-record/1"
var MAGIC = "# Clayground lab record v1 - JSON header, then tab-separated samples."
var SAMPLES_MARKER = "# samples"

// A record above this is summarized rather than committed in full (D9). 200 KB
// of text is roughly 3000 samples of eight probes: past that a record stops
// being something a reviewer reads and becomes an attachment.
var MAX_BYTES = 200 * 1024

// Significant figures for everything printed. Six is what an instrument
// reading is worth and what a results table can carry without lying.
var SIG_DIGITS = 6

// --- numbers ---------------------------------------------------------------

// The one number formatter. Non-finite is not a value: it prints as an empty
// cell, because "no measurement" and "zero" are different claims.
function num(v, sig) {
    // Number(null) is 0, and a summary with nothing in it must not print as a
    // measurement of zero - so the absent cases are rejected before the cast.
    if (v === null || v === undefined || v === "") return ""
    var x = Number(v)
    if (!isFinite(x)) return ""
    if (x === 0) return "0"
    var r = Number(x.toPrecision(sig === undefined ? SIG_DIGITS : sig))
    // String(Number) is the shortest round-tripping form and is spec-defined,
    // so it is stable across engines - but it switches to exponential notation
    // at 1e21 and below 1e-6, which is fine and still parses back.
    return String(r)
}

// --- streaming statistics --------------------------------------------------
//
// Welford's, one sample at a time. format.js has the batch form for a probe's
// retained ring; a recorder cannot use it, because a run may be far longer
// than the 1200 samples a Probe keeps. Same arithmetic, different arrival
// order - and Welford is the reason a 9.81 baseline with millimetre noise
// cannot come back with a negative variance.

function accInit() {
    return { count: 0, first: NaN, last: NaN, min: NaN, max: NaN,
             _mean: 0, _m2: 0 }
}

function accAdd(a, v) {
    var x = Number(v)
    if (!isFinite(x)) return a          // not a sample; the cell stays blank
    a.count += 1
    if (a.count === 1) { a.first = x; a.min = x; a.max = x }
    if (x < a.min) a.min = x
    if (x > a.max) a.max = x
    a.last = x
    var delta = x - a._mean
    a._mean += delta / a.count
    a._m2 += delta * (x - a._mean)
    return a
}

// The publishable form: population statistics, because a probe's series is the
// whole run being described, not a sample drawn from a larger population.
function accSummary(a) {
    if (!a || a.count === 0)
        return { count: 0, first: null, last: null, min: null, max: null,
                 mean: null, stddev: null }
    var variance = a._m2 / a.count
    if (variance < 0) variance = 0
    return { count: a.count, first: a.first, last: a.last,
             min: a.min, max: a.max, mean: a._mean,
             stddev: Math.sqrt(variance) }
}

// --- the record ------------------------------------------------------------
//
// A record object, as serialize() expects it:
//
//   { id, lab, scenario, seed, steps, stepSize, sampleInterval, duration,
//     command,
//     params:  [ {name, value, unit} ],
//     probes:  [ {name, unit, count, first, last, min, max, mean, stddev} ],
//     columns: ["t", <probe names in order>],
//     rows:    [ [t, v, v, ...] ]        // non-finite -> blank cell
//   }
//
// Everything except rows/columns is provenance: enough to regenerate the run
// and to know what it was a run OF.

function _jsonString(s) {
    return JSON.stringify(String(s === undefined || s === null ? "" : s))
}

function _jsonNum(v) {
    var t = num(v)
    return t === "" ? "null" : t
}

// One probe summary per line: a readable row, and a one-line diff when a
// statistic moves.
function _probeLine(p) {
    return '{"name": ' + _jsonString(p.name)
         + ', "unit": ' + _jsonString(p.unit || "")
         + ', "count": ' + (p.count | 0)
         + ', "first": ' + _jsonNum(p.first)
         + ', "last": ' + _jsonNum(p.last)
         + ', "min": ' + _jsonNum(p.min)
         + ', "max": ' + _jsonNum(p.max)
         + ', "mean": ' + _jsonNum(p.mean)
         + ', "stddev": ' + _jsonNum(p.stddev)
         + '}'
}

function _paramLine(p) {
    var line = '{"name": ' + _jsonString(p.name) + ', "value": ' + _jsonNum(p.value)
    if (p.unit) line += ', "unit": ' + _jsonString(p.unit)
    return line + '}'
}

function _header(rec, samples) {
    var L = []
    L.push('{')
    L.push('  "format": ' + _jsonString(FORMAT) + ',')
    L.push('  "id": ' + _jsonString(rec.id) + ',')
    L.push('  "lab": ' + _jsonString(rec.lab) + ',')
    L.push('  "scenario": ' + _jsonString(rec.scenario) + ',')
    L.push('  "seed": ' + ((rec.seed | 0)) + ',')
    L.push('  "steps": ' + ((rec.steps | 0)) + ',')
    L.push('  "stepSize": ' + _jsonNum(rec.stepSize) + ',')
    L.push('  "sampleInterval": ' + _jsonNum(rec.sampleInterval) + ',')
    L.push('  "duration": ' + _jsonNum(rec.duration) + ',')
    L.push('  "command": ' + _jsonString(rec.command) + ',')

    var params = rec.params || []
    if (params.length === 0) L.push('  "params": [],')
    else {
        L.push('  "params": [')
        for (var i = 0; i < params.length; ++i)
            L.push('    ' + _paramLine(params[i]) + (i < params.length - 1 ? ',' : ''))
        L.push('  ],')
    }

    var probes = rec.probes || []
    if (probes.length === 0) L.push('  "probes": [],')
    else {
        L.push('  "probes": [')
        for (var j = 0; j < probes.length; ++j)
            L.push('    ' + _probeLine(probes[j]) + (j < probes.length - 1 ? ',' : ''))
        L.push('  ],')
    }

    var s = '  "samples": {"columns": [' + (rec.columns || []).map(_jsonString).join(', ')
          + '], "count": ' + samples.count
          + ', "stride": ' + samples.stride
          + ', "recorded": ' + samples.recorded
    if (samples.stride > 1)
        s += ', "note": ' + _jsonString(
            "thinned to stay under the " + Math.round(MAX_BYTES / 1024)
            + " KB record limit; the summaries above are over ALL "
            + samples.recorded + " samples")
    L.push(s + '}')
    L.push('}')
    return L.join("\n")
}

function _table(rec, stride) {
    var L = [(rec.columns || []).join("\t")]
    var rows = rec.rows || []
    for (var i = 0; i < rows.length; i += stride) {
        var r = rows[i]
        var cells = []
        for (var c = 0; c < r.length; ++c) cells.push(num(r[c]))
        L.push(cells.join("\t"))
    }
    return L.join("\n")
}

function _compose(rec, stride) {
    var rows = rec.rows || []
    var kept = stride === 1 ? rows.length : Math.ceil(rows.length / stride)
    var samples = { count: kept, stride: stride, recorded: rows.length }
    return MAGIC + "\n" + _header(rec, samples) + "\n"
         + SAMPLES_MARKER + "\n" + _table(rec, stride) + "\n"
}

/*
    Serializes a record to its text form.

    opts.maxBytes (default 200 KB) is the D9 tripwire. A record over it is not
    dropped and not silently truncated: the sample table is thinned by the
    smallest whole stride that fits, the header says so, and the probe
    summaries stay computed over ALL samples - so the numbers a paper quotes
    are never the thinned ones.
*/
function serialize(rec, opts) {
    var maxBytes = (opts && opts.maxBytes) || MAX_BYTES
    var text = _compose(rec, 1)
    if (byteLength(text) <= maxBytes) return text

    // Header and table grow independently; size the stride from the table
    // alone, then confirm - a header with fifty probes could exceed the limit
    // by itself, in which case there is nothing left to thin and the record is
    // written oversized rather than lost.
    var stride = 2
    while (stride < 1e6) {
        text = _compose(rec, stride)
        if (byteLength(text) <= maxBytes) return text
        stride = Math.ceil(stride * 1.5)
    }
    return text
}

// UTF-8 length without TextEncoder (which QML's JS engine does not have).
// Only the multi-byte case matters for the tripwire, and units like "µ" and
// "Ω" are exactly that.
function byteLength(s) {
    var n = 0
    for (var i = 0; i < s.length; ++i) {
        var c = s.charCodeAt(i)
        if (c < 0x80) n += 1
        else if (c < 0x800) n += 2
        else if (c >= 0xd800 && c <= 0xdbff) { n += 4; ++i }   // surrogate pair
        else n += 3
    }
    return n
}

/*
    Parses a record back. Returns {header, columns, rows, series(name)} - the
    inverse of serialize() for everything a consumer needs (a sweep runner, a
    comparison overlay, a check that a paper still quotes what the record
    holds). Throws on anything that is not a record, rather than guessing.
*/
function parse(text) {
    var lines = String(text).split("\n")
    var i = 0
    while (i < lines.length && lines[i].indexOf("#") === 0) ++i
    var jsonLines = []
    while (i < lines.length && lines[i] !== SAMPLES_MARKER) {
        jsonLines.push(lines[i])
        ++i
    }
    if (i >= lines.length) throw new Error("record: no '" + SAMPLES_MARKER + "' marker")
    var header = JSON.parse(jsonLines.join("\n"))
    if (header.format !== FORMAT)
        throw new Error("record: unknown format " + header.format)

    ++i                                              // past the marker
    var columns = i < lines.length ? lines[i].split("\t") : []
    ++i
    var rows = []
    for (; i < lines.length; ++i) {
        if (lines[i] === "") continue
        var cells = lines[i].split("\t")
        var row = []
        for (var c = 0; c < cells.length; ++c)
            row.push(cells[c] === "" ? NaN : Number(cells[c]))
        rows.push(row)
    }
    return {
        header: header,
        columns: columns,
        rows: rows,
        // [{t, v}] for one column, blanks dropped - the shape a plot wants
        series: function (name) {
            var k = columns.indexOf(name)
            if (k < 0) throw new Error("record: no column " + name)
            var out = []
            for (var r = 0; r < rows.length; ++r)
                if (isFinite(rows[r][k])) out.push({ t: rows[r][0], v: rows[r][k] })
            return out
        },
        // the summary a paper quotes, by probe name
        probe: function (name) {
            var ps = header.probes || []
            for (var p = 0; p < ps.length; ++p) if (ps[p].name === name) return ps[p]
            return null
        }
    }
}

/*
    Builds the record object from a run's raw pieces. Kept separate from
    serialize() so a caller can inspect or amend a record before writing it,
    and so the assembly rules (column order, summary derivation) are testable
    without going through text.

    run: { id, lab, scenario, seed, steps, stepSize, sampleInterval, command,
           params: [{name, value, unit}],
           probes: [{name, unit}],          // column order
           rows:   [[t, v, ...]] }          // one row per sample tick
*/
function build(run) {
    var probes = run.probes || []
    var rows = run.rows || []
    var accs = []
    for (var p = 0; p < probes.length; ++p) accs.push(accInit())
    for (var r = 0; r < rows.length; ++r)
        for (var c = 0; c < probes.length; ++c) accAdd(accs[c], rows[r][c + 1])

    var summaries = []
    for (var q = 0; q < probes.length; ++q) {
        var s = accSummary(accs[q])
        s.name = probes[q].name
        s.unit = probes[q].unit || ""
        summaries.push(s)
    }
    var columns = ["t"]
    for (var k = 0; k < probes.length; ++k) columns.push(probes[k].name)

    var duration = rows.length ? rows[rows.length - 1][0] : 0
    return {
        id: run.id || "", lab: run.lab || "", scenario: run.scenario || "",
        seed: run.seed | 0, steps: run.steps | 0,
        stepSize: run.stepSize, sampleInterval: run.sampleInterval,
        duration: duration, command: run.command || "",
        params: run.params || [], probes: summaries,
        columns: columns, rows: rows
    }
}
