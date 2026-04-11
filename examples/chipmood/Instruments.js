// SNES-style instrument patch definitions for ChipTracker
// Each patch bundles waveform + ADSR + gain + optional pitch envelope and LFO
// behind a friendly name — no synthesis knowledge needed to pick one.
//
// Portable: used by QML/JS (desktop + future WASM).

.pragma library

var patches = {
    // ═══════════════════════════════════════════
    // LEAD / MELODY
    // ═══════════════════════════════════════════
    synthLead: {
        name: "Synth Lead", category: "lead",
        waveform: "square",
        attack: 0.01, decay: 0.15, sustain: 0.7, release: 0.2,
        gain: 0.30
    },
    fluteSoft: {
        name: "Soft Flute", category: "lead",
        waveform: "sine",
        attack: 0.08, decay: 0.1, sustain: 0.6, release: 0.3,
        gain: 0.25,
        lfoRate: 5.0, lfoDepth: 0.15, lfoTarget: "pitch"
    },
    trumpetBright: {
        name: "Bright Trumpet", category: "lead",
        waveform: "sawtooth",
        attack: 0.03, decay: 0.12, sustain: 0.65, release: 0.15,
        gain: 0.28
    },
    organTone: {
        name: "Organ", category: "lead",
        waveform: "sine",
        attack: 0.005, decay: 0.05, sustain: 0.85, release: 0.1,
        gain: 0.22
    },

    // ═══════════════════════════════════════════
    // ARPEGGIO / TEXTURE
    // ═══════════════════════════════════════════
    chipBell: {
        name: "Chip Bell", category: "arp",
        waveform: "square",
        attack: 0.005, decay: 0.18, sustain: 0.15, release: 0.1,
        gain: 0.28
    },
    crystalArp: {
        name: "Crystal Arp", category: "arp",
        waveform: "sine",
        attack: 0.003, decay: 0.12, sustain: 0.1, release: 0.08,
        gain: 0.25
    },
    marimba: {
        name: "Marimba", category: "arp",
        waveform: "triangle",
        attack: 0.002, decay: 0.2, sustain: 0.05, release: 0.1,
        gain: 0.30
    },
    pizzicato: {
        name: "Pizzicato", category: "arp",
        waveform: "sawtooth",
        attack: 0.002, decay: 0.1, sustain: 0.0, release: 0.05,
        gain: 0.25
    },
    harpPluck: {
        name: "Harp Pluck", category: "arp",
        waveform: "triangle",
        attack: 0.003, decay: 0.25, sustain: 0.1, release: 0.15,
        gain: 0.22
    },

    // ═══════════════════════════════════════════
    // PAD / ATMOSPHERE
    // ═══════════════════════════════════════════
    softPad: {
        name: "Soft Pad", category: "pad",
        waveform: "sine",
        attack: 0.3, decay: 0.2, sustain: 0.6, release: 0.5,
        gain: 0.18
    },
    warmPad: {
        name: "Warm Pad", category: "pad",
        waveform: "triangle",
        attack: 0.25, decay: 0.15, sustain: 0.65, release: 0.4,
        gain: 0.18
    },
    ghostPad: {
        name: "Ghost Pad", category: "pad",
        waveform: "sine",
        attack: 0.5, decay: 0.3, sustain: 0.4, release: 0.8,
        gain: 0.15
    },
    choirPad: {
        name: "Choir", category: "pad",
        waveform: "triangle",
        attack: 0.2, decay: 0.2, sustain: 0.6, release: 0.4,
        gain: 0.16,
        lfoRate: 4.0, lfoDepth: 0.2, lfoTarget: "pitch"
    },

    // ═══════════════════════════════════════════
    // BASS
    // ═══════════════════════════════════════════
    fatBass: {
        name: "Fat Bass", category: "bass",
        waveform: "square",
        attack: 0.008, decay: 0.12, sustain: 0.6, release: 0.15,
        gain: 0.28
    },
    deepBass: {
        name: "Deep Bass", category: "bass",
        waveform: "triangle",
        attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.2,
        gain: 0.25
    },
    acidBass: {
        name: "Acid Bass", category: "bass",
        waveform: "sawtooth",
        attack: 0.005, decay: 0.15, sustain: 0.5, release: 0.1,
        gain: 0.25,
        lfoRate: 3.0, lfoDepth: 0.1, lfoTarget: "pitch"
    },
    pluckBass: {
        name: "Pluck Bass", category: "bass",
        waveform: "sawtooth",
        attack: 0.003, decay: 0.18, sustain: 0.15, release: 0.1,
        gain: 0.28
    },
    subBass: {
        name: "Sub Bass", category: "bass",
        waveform: "sine",
        attack: 0.02, decay: 0.1, sustain: 0.8, release: 0.25,
        gain: 0.22
    },

    // ═══════════════════════════════════════════
    // PERCUSSION
    // ═══════════════════════════════════════════
    kick: {
        name: "Kick", category: "perc",
        waveform: "noise",
        attack: 0.001, decay: 0.12, sustain: 0.0, release: 0.05,
        gain: 0.30,
        pitchStart: 24, pitchEnd: 0, pitchTime: 0.04
    },
    snare: {
        name: "Snare", category: "perc",
        waveform: "noise",
        attack: 0.001, decay: 0.15, sustain: 0.05, release: 0.08,
        gain: 0.22
    },
    hihat: {
        name: "Hi-Hat", category: "perc",
        waveform: "noise",
        attack: 0.001, decay: 0.04, sustain: 0.0, release: 0.02,
        gain: 0.15
    },
    tom: {
        name: "Tom", category: "perc",
        waveform: "noise",
        attack: 0.001, decay: 0.18, sustain: 0.0, release: 0.08,
        gain: 0.25,
        pitchStart: 12, pitchEnd: 0, pitchTime: 0.06
    }
}

// Ordered list for UI display
var categories = ["lead", "arp", "pad", "bass", "perc"]

var patchIds = Object.keys(patches)

// Get patches filtered by category
function byCategory(cat) {
    return patchIds.filter(function(id) { return patches[id].category === cat })
}

// Default patch assignments for generated channels
var defaultChannelPatches = {
    arp:    "chipBell",
    melody: "synthLead",
    pad:    "softPad",
    bass:   "deepBass",
    perc:   "kick"
}

// Warm variants (used when preset warmth > 0.6)
var warmChannelPatches = {
    arp:    "marimba",
    melody: "fluteSoft",
    pad:    "warmPad",
    bass:   "fatBass",
    perc:   "kick"
}
