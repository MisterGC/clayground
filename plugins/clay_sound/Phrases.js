// Pre-built pattern phrases for ChipTracker
// Each phrase is 16 steps of scale degrees (-1 = rest).
// Tile to fill longer patterns; role tags help the UI suggest appropriate phrases.

.pragma library

var phrases = {
    // ═══════════════════════════════════════════
    // ARPEGGIO PHRASES
    // ═══════════════════════════════════════════
    arpRising: {
        name: "Rising",
        role: "arp",
        steps: [0,2,4,6, 0,2,4,6, 0,2,4,6, 0,2,4,6]
    },
    arpFalling: {
        name: "Falling",
        role: "arp",
        steps: [6,4,2,0, 6,4,2,0, 6,4,2,0, 6,4,2,0]
    },
    arpWave: {
        name: "Wave",
        role: "arp",
        steps: [0,2,4,6, 4,2,0,-1, 0,2,4,6, 4,2,0,-1]
    },
    arpBroken: {
        name: "Broken Chord",
        role: "arp",
        steps: [0,4,2,6, 0,4,2,6, 0,4,2,6, 0,4,2,6]
    },
    arpSparse: {
        name: "Sparse",
        role: "arp",
        steps: [0,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1, 6,-1,-1,-1]
    },
    arpPulse: {
        name: "Pulse",
        role: "arp",
        steps: [0,-1,2,-1, 0,-1,2,-1, 0,-1,4,-1, 0,-1,2,-1]
    },
    arpFlowing: {
        name: "Flowing",
        role: "arp",
        steps: [0,2,4,6, 0,2,4,7, 0,2,5,6, 0,2,4,6]
    },
    arpCrystal: {
        name: "Crystal",
        role: "arp",
        steps: [0,-1,4,-1, 7,-1,4,-1, 0,-1,5,-1, 7,-1,5,-1]
    },

    // ═══════════════════════════════════════════
    // MELODY PHRASES
    // ═══════════════════════════════════════════
    melStepwise: {
        name: "Stepwise",
        role: "melody",
        steps: [0,-1,1,-1, 2,-1,3,-1, 4,-1,3,-1, 2,-1,1,-1]
    },
    melLeaps: {
        name: "Leaps",
        role: "melody",
        steps: [0,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1, 6,-1,-1,-1]
    },
    melCallResponse: {
        name: "Call & Response",
        role: "melody",
        steps: [4,3,2,1, -1,-1,-1,-1, 2,3,4,5, -1,-1,-1,-1]
    },
    melDescend: {
        name: "Descending",
        role: "melody",
        steps: [6,-1,5,-1, 4,-1,3,-1, 2,-1,1,-1, 0,-1,-1,-1]
    },
    melBouncy: {
        name: "Bouncy",
        role: "melody",
        steps: [0,2,4,2, 0,2,4,5, 4,2,0,2, 4,5,4,-1]
    },
    melMajestic: {
        name: "Majestic",
        role: "melody",
        steps: [4,-1,5,-1, 7,-1,-1,-1, 5,-1,4,-1, 2,-1,-1,-1]
    },

    // ═══════════════════════════════════════════
    // PAD PHRASES
    // ═══════════════════════════════════════════
    padSustain: {
        name: "Sustained",
        role: "pad",
        steps: [0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1]
    },
    padPulse: {
        name: "Pulse",
        role: "pad",
        steps: [0,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1]
    },
    padTwoNote: {
        name: "Two-Note",
        role: "pad",
        steps: [0,-1,-1,-1, -1,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1]
    },
    padDrone: {
        name: "Drone",
        role: "pad",
        steps: [0,-1,-1,-1, 0,-1,-1,-1, 0,-1,-1,-1, 0,-1,-1,-1]
    },
    padShimmer: {
        name: "Shimmer",
        role: "pad",
        steps: [0,2,4,2, 0,2,4,2, 0,2,4,2, 0,2,4,2]
    },

    // ═══════════════════════════════════════════
    // BASS PHRASES
    // ═══════════════════════════════════════════
    bassWalking: {
        name: "Walking",
        role: "bass",
        steps: [0,-1,-1,-1, 4,-1,-1,-1, 0,-1,-1,-1, 2,-1,-1,-1]
    },
    bassSteady: {
        name: "Steady",
        role: "bass",
        steps: [0,-1,0,-1, 0,-1,0,-1, 0,-1,0,-1, 0,-1,0,-1]
    },
    bassDriving: {
        name: "Driving",
        role: "bass",
        steps: [0,0,0,0, 0,0,2,0, 0,0,0,0, 3,0,2,0]
    },
    bassMinimal: {
        name: "Minimal",
        role: "bass",
        steps: [0,-1,-1,-1, -1,-1,-1,-1, 2,-1,-1,-1, -1,-1,-1,-1]
    },
    bassBounce: {
        name: "Bounce",
        role: "bass",
        steps: [0,-1,0,-1, 2,-1,0,-1, 0,-1,0,-1, 4,-1,2,-1]
    },
    bassGentle: {
        name: "Gentle",
        role: "bass",
        steps: [0,-1,0,-1, 2,-1,0,-1, 0,-1,0,-1, 4,-1,2,-1]
    },

    // ═══════════════════════════════════════════
    // PERCUSSION PHRASES (0 = hit, -1 = rest)
    // ═══════════════════════════════════════════
    percBasic: {
        name: "Basic Beat",
        role: "perc",
        steps: [0,-1,-1,-1, 0,-1,-1,-1, 0,-1,-1,-1, 0,-1,0,-1]
    },
    percSparse: {
        name: "Sparse",
        role: "perc",
        steps: [0,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1]
    },
    percDrips: {
        name: "Drips",
        role: "perc",
        steps: [-1,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1, -1,-1,0,-1]
    },
    percDriving: {
        name: "Driving",
        role: "perc",
        steps: [0,-1,0,-1, 0,-1,0,-1, 0,-1,0,-1, 0,-1,-1,0]
    },
    percSyncopated: {
        name: "Syncopated",
        role: "perc",
        steps: [0,-1,-1,0, -1,-1,0,-1, -1,0,-1,-1, 0,-1,-1,-1]
    }
}

var roles = ["arp", "melody", "pad", "bass", "perc"]

var phraseIds = Object.keys(phrases)

function byRole(role) {
    return phraseIds.filter(function(id) { return phrases[id].role === role })
}
