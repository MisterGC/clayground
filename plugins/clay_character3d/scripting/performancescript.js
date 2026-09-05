// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The performance script parser - one string in, a cue list out.
//
// A performance script is what a director hands an actor: speech and stage
// directions in the order they happen, in one artifact that can be diffed,
// translated and asserted on. It extends the annotation syntax the character
// plugin already publishes (`say("*happy* ...")`), so a directive is anything
// between two asterisks and everything else is spoken.
//
//     *point at battery* This is the battery. (2s)
//     *face viewer* *happy* It stores the energy our circuit spends.
//
// The vocabulary is fixed and the arguments are unambiguous: the format reads
// like stage direction but leaves nothing to interpretation. Two rules carry
// most of that weight:
//
//   * STRICT BY DEFAULT. An unknown directive is a reported error with its
//     position in the source, never spoken dialogue - a typo must not end up
//     in the character's mouth. The lenient mode reproduces what `say()` does
//     today (an unrecognised annotation stays in the text) and exists for
//     compatibility, not for authoring.
//   * DIRECTIVES ARE INSTANT. Only speech and an explicit `*pause*` consume
//     time, so "point at it WHILE saying this" - the single most common thing
//     a teacher does - is the natural thing to write. A speech run may carry a
//     trailing time hint, `(2s)`, which then decides that line's duration
//     instead of the speech engine's estimate.
//
// This module is deliberately Qt-free: no Qt types, no clock, no randomness.
// It parses and it compares, nothing else, which is why the sequencer
// (Performance.qml) can be swapped out and why the suite next door runs under
// plain node in a second:
//
//     node plugins/clay_character3d/scripting/performancescript.test.js
//
// The cue list is the intermediate form. A bigger scheduler - several
// performers, a whole scene - can consume the same list, and nothing in the
// grammar names a single character.

// --- vocabulary --------------------------------------------------------------

// Emotions, with the aliases the plugin's say() already accepts. The empty
// string is the neutral face, as in Character's own parser.
var EMOTIONS = {
    happy: "happy", joy: "happy",
    sad: "sad", sadness: "sad",
    angry: "angry", anger: "angry",
    neutral: "", calm: ""
}

// Directives that take no argument.
var PLAIN = {
    "thumbs up": "thumbsUp",
    "gesticulate": "gesticulate",
    "rest": "rest"
}

// Directives that take the rest of the line as their argument. The argument is
// a QML objectName - the scene resolves it, the character never knows about it.
var TARGETED = {
    "point at": "point",
    // The open hand offered toward a thing - for a group or an area, where a
    // finger would point at nothing in particular. "show" is the same cue
    // under the word a script author reaches for first.
    "present": "present",
    "show": "present",
    "look at": "look",
    "face": "face",
    // Markers on the things a line names, for as long as that line lasts.
    // Several at once, comma separated - "the battery, the switch, the LED" -
    // because naming a group is exactly when a marker earns its keep, and a
    // sentence that lists four parts is one sentence.
    "mark": "mark"
}

// The one reserved target: wherever the camera is. Case-insensitive, and
// normalised to lower case so a resolver only has to check one spelling.
var VIEWER = "viewer"

// A duration, on a pause directive or as a speech hint: number + unit, both
// required. "800ms", "2s", "1.5s". No unit is an error rather than a guess.
var DURATION_RE = /^(\d+(?:\.\d+)?)\s*(ms|s)$/i

// A time hint: a duration in parentheses at the very END of a speech run,
// separated from the text by whitespace. Anything else - mid-run, or glued to
// the last word - is text. The rule stays this blunt on purpose: an author
// should be able to tell hint from prose without consulting the grammar.
var HINT_RE = /\s\((\d+(?:\.\d+)?)\s*(ms|s)\)$/i

// "a, b ,c" -> ["a", "b", "c"]. Empty entries are dropped rather than
// resolved: a trailing comma is a typo, not a target called "".
function _splitTargets(text) {
    var out = []
    var parts = ("" + text).split(",")
    for (var i = 0; i < parts.length; ++i) {
        var t = parts[i].trim()
        if (t !== "")
            out.push(t)
    }
    return out
}

function _toMs(value, unit) {
    var n = parseFloat(value)
    return Math.round(unit.toLowerCase() === "s" ? n * 1000 : n)
}

// null when the text is not a well-formed duration.
function _durationMs(text) {
    var m = DURATION_RE.exec(text)
    return m === null ? null : _toMs(m[1], m[2])
}

function _normalizeVerbs(verbs) {
    var out = []
    if (!verbs)
        return out
    for (var i = 0; i < verbs.length; ++i) {
        var v = ("" + verbs[i]).trim().replace(/\s+/g, " ").toLowerCase()
        if (v !== "")
            out.push(v)
    }
    // Longest first, so "board out fast" wins over "board out".
    out.sort(function (a, b) { return b.length - a.length })
    return out
}

// --- one directive -----------------------------------------------------------

// Turns the normalized inner text of a *...* into a cue. Returns
// { cue: {...} } or { error: "message" } - the caller decides what an error
// means (reported in strict mode, plain text in lenient mode).
function _directive(norm, at, extraVerbs) {
    var low = norm.toLowerCase()

    if (EMOTIONS[low] !== undefined)
        return { cue: { type: "emotion", value: EMOTIONS[low], at: at } }

    if (PLAIN[low] !== undefined)
        return { cue: { type: PLAIN[low], at: at } }

    for (var verb in TARGETED) {
        if (low === verb)
            return { error: "'" + verb + "' needs a target name" }
        if (low.indexOf(verb + " ") === 0) {
            // The name is taken verbatim from the source: targets are
            // objectNames and QML is case-sensitive about those.
            var target = norm.substring(verb.length + 1).trim()
            if (target.toLowerCase() === VIEWER)
                target = VIEWER
            if (TARGETED[verb] === "mark") {
                var names = _splitTargets(target)
                if (names.length === 0)
                    return { error: "'mark' needs a target name" }
                // `target` stays the canonical spelling of the whole list, so
                // describe() and the cross-language lint compare one string.
                return { cue: { type: "mark", target: names.join(", "),
                                targets: names, at: at } }
            }
            return { cue: { type: TARGETED[verb], target: target, at: at } }
        }
    }

    if (low === "pause")
        return { error: "'pause' needs a duration, e.g. 800ms or 1.5s" }
    if (low.indexOf("pause ") === 0) {
        var ms = _durationMs(norm.substring(6).trim())
        if (ms === null)
            return { error: "unparsable duration '" + norm.substring(6).trim()
                            + "' - use 800ms, 2s or 1.5s" }
        return { cue: { type: "pause", ms: ms, at: at } }
    }

    for (var i = 0; i < extraVerbs.length; ++i) {
        var e = extraVerbs[i]
        if (low === e)
            return { cue: { type: "custom", verb: e, arg: "", at: at } }
        if (low.indexOf(e + " ") === 0)
            return { cue: { type: "custom", verb: e,
                            arg: norm.substring(e.length + 1).trim(), at: at } }
    }

    return { error: "unknown directive '" + norm + "'" }
}

// --- the parser --------------------------------------------------------------

/*
    parse(script, options) -> { cues: [...], errors: [...] }

    options.strict      default true. An unknown directive, an empty `**` and
                        an unterminated `*` are errors; in lenient mode each of
                        them stays in the spoken text, which is what say() does
                        today.
    options.extraVerbs  additional directive names (lower case, may contain
                        spaces) that parse into { type: "custom", verb, arg }.
                        This is the registration seam for actions only one
                        character has; the built-in vocabulary always wins.

    Every cue carries `at`, the character index in the source where it starts,
    so an error message and a debug log can point at the script rather than at
    the cue number.
*/
function parse(script, options) {
    var opts = options || {}
    var strict = opts.strict === undefined ? true : !!opts.strict
    var extraVerbs = _normalizeVerbs(opts.extraVerbs)
    var src = (script === undefined || script === null) ? "" : "" + script

    var cues = []
    var errors = []
    var buf = ""    // the speech run being collected, verbatim
    var bufAt = -1  // where its first non-space character sits in the source

    function text(chunk, at) {
        if (chunk === "")
            return
        if (bufAt < 0) {
            var lead = chunk.search(/\S/)
            if (lead >= 0)
                bufAt = at + lead
        }
        buf += chunk
    }

    // A directive ends the run before it; so does the end of the script.
    function flush() {
        var trimmed = buf.trim()
        var at = bufAt < 0 ? 0 : bufAt
        buf = ""
        bufAt = -1
        if (trimmed === "")
            return
        var hintMs = null
        var h = HINT_RE.exec(trimmed)
        if (h !== null) {
            hintMs = _toMs(h[1], h[2])
            trimmed = trimmed.substring(0, h.index).trim()
        }
        cues.push({ type: "say", text: trimmed, hintMs: hintMs, at: at })
    }

    var i = 0
    while (i < src.length) {
        var star = src.indexOf("*", i)
        if (star < 0) {
            text(src.substring(i), i)
            break
        }
        text(src.substring(i, star), i)

        var end = src.indexOf("*", star + 1)
        if (end < 0) {
            if (strict)
                errors.push({ at: star, directive: src.substring(star + 1).trim(),
                              message: "unterminated '*' - a directive needs a closing asterisk" })
            else
                text(src.substring(star), star)
            i = src.length
            break
        }

        var norm = src.substring(star + 1, end).trim().replace(/\s+/g, " ")
        i = end + 1

        if (norm === "") {
            if (strict)
                errors.push({ at: star, directive: "", message: "empty directive '**'" })
            else
                text(src.substring(star, end + 1), star)
            continue
        }

        var d = _directive(norm, star, extraVerbs)
        if (d.error !== undefined) {
            if (strict) {
                // The author meant a directive, so it still ends the run - it
                // just never becomes one, and it is never spoken.
                flush()
                errors.push({ at: star, directive: norm, message: d.error })
            } else {
                text(src.substring(star, end + 1), star)
            }
            continue
        }

        flush()
        cues.push(d.cue)
    }
    flush()

    return { cues: cues, errors: errors }
}

// --- describing --------------------------------------------------------------

/*
    describe(cue) -> a short line for a log or an inspector. Stable enough to
    assert on: the sequencer publishes it as `currentCue`.
*/
function describe(cue) {
    if (!cue || !cue.type)
        return "?"
    switch (cue.type) {
    case "emotion":
        return "emotion " + (cue.value === "" ? "neutral" : cue.value)
    case "point":
        return "point at " + cue.target
    case "present":
        return "present " + cue.target
    case "look":
        return "look at " + cue.target
    case "face":
        return "face " + cue.target
    case "mark":
        return "mark " + cue.target
    case "thumbsUp":
        return "thumbs up"
    case "gesticulate":
        return "gesticulate"
    case "rest":
        return "rest"
    case "pause":
        return "pause " + cue.ms + "ms"
    case "custom":
        return cue.arg ? cue.verb + " " + cue.arg : cue.verb
    case "say":
        var t = cue.text.length > 24
                ? cue.text.substring(0, 24).replace(/\s+$/, "") + "…"
                : cue.text
        return "say '" + t + "'"
               + (cue.hintMs === null || cue.hintMs === undefined
                  ? "" : " (" + cue.hintMs + "ms)")
    }
    return cue.type
}

// --- the cross-language check ------------------------------------------------

function _isDirective(cue) { return cue.type !== "say" }

// The part of a cue a translator must not change.
function _argOf(cue) {
    switch (cue.type) {
    case "emotion": return cue.value
    case "point": case "present": case "look": case "face": case "mark":
        return cue.target
    case "pause": return "" + cue.ms
    case "custom": return cue.arg
    }
    return ""
}

/*
    lint(scriptA, scriptB, options) -> [ { index, a, b, message }, ... ]

    Compares the DIRECTIVE sequences of the same script in two languages,
    ignoring the spoken text and the time hints - those are supposed to differ.
    An empty list means the two are in sync. Direction lives inside the
    translated string, so this is what keeps a translator from reordering,
    dropping or rewording a stage direction by accident.

    `a` and `b` are describe() strings, null where a directive is absent.
*/
function lint(scriptA, scriptB, options) {
    var a = parse(scriptA, options).cues.filter(_isDirective)
    var b = parse(scriptB, options).cues.filter(_isDirective)
    var out = []
    var n = Math.max(a.length, b.length)
    for (var i = 0; i < n; ++i) {
        var ca = i < a.length ? a[i] : null
        var cb = i < b.length ? b[i] : null
        if (ca === null) {
            out.push({ index: i, a: null, b: describe(cb),
                       message: "extra directive in b: " + describe(cb) })
        } else if (cb === null) {
            out.push({ index: i, a: describe(ca), b: null,
                       message: "missing in b: " + describe(ca) })
        } else if (ca.type !== cb.type) {
            out.push({ index: i, a: describe(ca), b: describe(cb),
                       message: "directive mismatch: " + describe(ca) + " vs " + describe(cb) })
        } else if (_argOf(ca) !== _argOf(cb)) {
            out.push({ index: i, a: describe(ca), b: describe(cb),
                       message: "argument differs: " + describe(ca) + " vs " + describe(cb) })
        }
    }
    return out
}
