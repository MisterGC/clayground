// ChipMood environment presets — RPG-themed mood configurations
// These define the musical character for each environment type.

.pragma library

var environments = {
    forest: {
        name: "Mysterious Forest",
        tempoRange: [75, 95], rootRange: [48, 55],
        echo: 0.3, warmth: 0.6,
        arpStyle: "flowing", padStyle: "sustained",
        bassStyle: "gentle", percStyle: "none",
        defaultScale: "dorian",
        sectionPattern: [16, 16, 16, 8]
    },
    dungeon: {
        name: "Dark Dungeon",
        tempoRange: [90, 110], rootRange: [43, 50],
        echo: 0.4, warmth: 0.75,
        arpStyle: "pulsing", padStyle: "dark",
        bassStyle: "driving", percStyle: "sparse",
        defaultScale: "phrygian",
        sectionPattern: [16, 16, 16, 16]
    },
    village: {
        name: "Peaceful Village",
        tempoRange: [85, 105], rootRange: [53, 60],
        echo: 0.2, warmth: 0.45,
        arpStyle: "bright", padStyle: "warm",
        bassStyle: "walking", percStyle: "none",
        defaultScale: "major",
        sectionPattern: [12, 12, 12, 12]
    },
    cave: {
        name: "Deep Cave",
        tempoRange: [60, 80], rootRange: [36, 46],
        echo: 0.6, warmth: 0.8,
        arpStyle: "sparse", padStyle: "droning",
        bassStyle: "rumbling", percStyle: "drips",
        defaultScale: "minor",
        sectionPattern: [20, 16, 20, 12]
    },
    mountain: {
        name: "Mountain Peak",
        tempoRange: [70, 90], rootRange: [50, 58],
        echo: 0.35, warmth: 0.35,
        arpStyle: "majestic", padStyle: "airy",
        bassStyle: "grounded", percStyle: "none",
        defaultScale: "lydian",
        sectionPattern: [16, 12, 16, 8]
    },
    ocean: {
        name: "Ocean Voyage",
        tempoRange: [65, 85], rootRange: [45, 53],
        echo: 0.45, warmth: 0.55,
        arpStyle: "wave", padStyle: "flowing",
        bassStyle: "deep", percStyle: "none",
        defaultScale: "mixolydian",
        sectionPattern: [14, 14, 14, 14]
    },
    desert: {
        name: "Desert Sands",
        tempoRange: [80, 100], rootRange: [48, 55],
        echo: 0.25, warmth: 0.4,
        arpStyle: "exotic", padStyle: "shimmering",
        bassStyle: "sparse", percStyle: "rhythmic",
        defaultScale: "phrygian",
        sectionPattern: [16, 8, 16, 8]
    },
    snow: {
        name: "Frozen Tundra",
        tempoRange: [55, 75], rootRange: [50, 58],
        echo: 0.5, warmth: 0.25,
        arpStyle: "crystalline", padStyle: "ethereal",
        bassStyle: "minimal", percStyle: "none",
        defaultScale: "pentatonic",
        sectionPattern: [18, 18, 12, 12]
    }
}

var icons = {
    forest: "\u{1F332}", dungeon: "\u{1F480}", village: "\u{1F3E0}", cave: "\u{1F987}",
    mountain: "\u{1F3D4}", ocean: "\u{1F30A}", desert: "\u{1F3DC}", snow: "\u{2744}"
}

var descriptions = {
    forest: "Mysterious, ethereal",
    dungeon: "Dark, tense",
    village: "Peaceful, bright",
    cave: "Deep, echoing",
    mountain: "Majestic, airy",
    ocean: "Flowing, rolling",
    desert: "Exotic, shimmering",
    snow: "Crystalline, cold"
}

var names = Object.keys(environments)
