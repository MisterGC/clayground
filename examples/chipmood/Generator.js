// Pattern generation logic for ChipTracker
// Fills the step grid from environment presets — portable JS.

.pragma library

function createRng(seed) {
    var state = seed >>> 0
    return function() {
        state = (state + 0x6D2B79F5) >>> 0
        var t = state
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

// ── Pattern generators (ported from ChipMood) ─────────────

function arpPattern(style) {
    var p = {
        flowing:     [0,2,4,6, 0,2,4,7, 0,2,5,6, 0,2,4,6],
        pulsing:     [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,2,0],
        bright:      [0,2,4,2, 0,2,4,5, 0,2,4,2, 0,4,2,0],
        sparse:      [0,-1,-1,-1, 2,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1],
        majestic:    [0,-1,4,-1, 0,-1,7,-1, 0,-1,4,-1, 0,-1,5,-1],
        wave:        [0,1,2,3, 4,3,2,1, 0,1,2,3, 4,5,4,3],
        exotic:      [0,1,4,1, 0,1,5,1, 0,1,4,1, 0,3,1,0],
        crystalline: [0,-1,4,-1, 7,-1,4,-1, 0,-1,5,-1, 7,-1,5,-1]
    }
    return p[style] || p.flowing
}

function melodyPattern(style) {
    var p = {
        flowing:     [4,3,2,1, 2,-1,-1,-1, 4,5,4,3, 2,-1,-1,-1],
        pulsing:     [0,-1,1,-1, 0,-1,-1,-1, -1,-1,2,-1, 1,-1,-1,-1],
        bright:      [4,2,0,2, 4,4,4,-1, 5,4,2,4, 5,5,5,-1],
        sparse:      [2,-1,-1,-1, -1,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1],
        majestic:    [4,-1,5,-1, 7,-1,-1,-1, 5,-1,4,-1, 2,-1,-1,-1],
        wave:        [2,3,4,5, 4,3,2,-1, 3,4,5,6, 5,4,3,-1],
        exotic:      [0,1,3,-1, 5,-1,-1,-1, 3,1,0,-1, -1,-1,-1,-1],
        crystalline: [7,-1,-1,-1, 5,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1]
    }
    return p[style] || p.flowing
}

function bassPattern(style) {
    var p = {
        gentle:   [0,-1,0,-1, 2,-1,0,-1, 0,-1,0,-1, 4,-1,2,-1],
        driving:  [0,0,0,0, 0,0,2,0, 0,0,0,0, 3,0,2,0],
        walking:  [0,-1,4,-1, 0,-1,4,-1, 2,-1,4,-1, 0,-1,2,-1],
        rumbling: [0,-1,-1,-1, -1,-1,0,-1, -1,-1,-1,-1, 0,-1,-1,-1],
        grounded: [0,-1,-1,-1, 0,-1,2,-1, 0,-1,-1,-1, 0,-1,4,-1],
        deep:     [0,-1,0,-1, -1,-1,0,-1, 2,-1,0,-1, -1,-1,2,-1],
        sparse:   [0,-1,-1,-1, -1,-1,-1,-1, 2,-1,-1,-1, -1,-1,-1,-1],
        minimal:  [0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1]
    }
    return p[style] || p.gentle
}

function padPattern(style) {
    var p = {
        sustained:  [0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1],
        dark:       [0,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1],
        warm:       [0,-1,-1,-1, 4,-1,-1,-1, 0,-1,-1,-1, 4,-1,-1,-1],
        droning:    [0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1],
        airy:       [4,-1,-1,-1, -1,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1],
        flowing:    [0,-1,-1,-1, 2,-1,-1,-1, 0,-1,-1,-1, 4,-1,-1,-1],
        shimmering: [0,2,4,2, 0,2,4,2, 0,2,4,2, 0,2,4,2],
        ethereal:   [4,-1,-1,-1, -1,-1,-1,-1, 7,-1,-1,-1, -1,-1,-1,-1]
    }
    return p[style] || p.sustained
}

// ── Tiling helpers ─────────────────────────────────────────

function tile(pat, len) {
    var result = []
    for (var i = 0; i < len; i++) result.push(pat[i % pat.length])
    return result
}

function toHalfNote(pat, len) {
    var result = []
    for (var i = 0; i < len; i++) {
        if (i % 2 === 0) result.push(pat[(i / 2) % pat.length])
        else result.push(-1)
    }
    return result
}

// ── Main generator ─────────────────────────────────────────

function generate(presetConfig, scaleName, seed, steps) {
    var rng = createRng(seed)
    var warmth = presetConfig.warmth || 0.5

    var tempo = presetConfig.tempoRange[0] +
        Math.floor(rng() * (presetConfig.tempoRange[1] - presetConfig.tempoRange[0]))
    var rootNote = presetConfig.rootRange[0] +
        Math.floor(rng() * (presetConfig.rootRange[1] - presetConfig.rootRange[0]))

    var arpPat  = arpPattern(presetConfig.arpStyle)
    var melPat  = melodyPattern(presetConfig.arpStyle)
    var padPat  = padPattern(presetConfig.padStyle)
    var bassPat = bassPattern(presetConfig.bassStyle)

    return {
        tempo: tempo,
        rootNote: rootNote,
        scale: presetConfig.defaultScale || scaleName,
        echoMix: presetConfig.echo || 0.3,
        brightness: Math.max(0.0, Math.min(1.0, 1.0 - warmth)),
        channels: [
            {
                role: "arp",
                patch: warmth > 0.6 ? "marimba" : "chipBell",
                octave: 1,
                pattern: tile(arpPat, steps)
            },
            {
                role: "melody",
                patch: warmth > 0.5 ? "fluteSoft" : "synthLead",
                octave: 0,
                pattern: toHalfNote(melPat, steps)
            },
            {
                role: "pad",
                patch: warmth > 0.6 ? "warmPad" : "softPad",
                octave: -1,
                pattern: tile(padPat, steps)
            },
            {
                role: "bass",
                patch: warmth > 0.6 ? "fatBass" : "deepBass",
                octave: -2,
                pattern: toHalfNote(bassPat, steps)
            }
        ]
    }
}
