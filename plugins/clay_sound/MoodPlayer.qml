// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype MoodPlayer
    \inqmlmodule Clayground.Sound
    \inherits ChipMood
    \brief SNES-style atmospheric music generator with customizable environments and scales.

    MoodPlayer creates procedural atmospheric music inspired by classic SNES RPG
    soundtracks like Chrono Trigger, Secret of Mana, and Zelda: A Link to the Past.

    The generator is fully deterministic - the same seed with identical parameters
    will always produce the exact same music, enabling easy sharing of compositions.

    \section1 Basic Usage

    \qml
    import Clayground.Sound

    MoodPlayer {
        id: music
        environment: "cave"
        scale: "dorian"
        seed: 42
        volume: 0.7
        intensity: 0.5
        onReadyChanged: if (ready) play()
    }
    \endqml

    \section1 Share Codes

    Share compositions using the shareCode property:
    \qml
    // Get shareable code
    console.log(music.shareCode)  // "cave-dor-ampb-50-30-85-42"

    // Apply shared code
    music.shareCode = "mountain-pent-amb-80-20-90-1337"
    \endqml

    \section1 Available Environments

    \table
    \header
        \li Environment
        \li Character
        \li Default Scale
    \row
        \li \c forest
        \li Mysterious, flowing arpeggios (Secret of Mana style)
        \li dorian
    \row
        \li \c dungeon
        \li Dark, pulsing tension (Dark World style)
        \li phrygian
    \row
        \li \c village
        \li Peaceful, bright melodies (Kakariko Village style)
        \li major
    \row
        \li \c cave
        \li Deep, echoing drones with water drips
        \li minor
    \row
        \li \c mountain
        \li Majestic, airy atmosphere
        \li lydian
    \row
        \li \c ocean
        \li Rolling wave patterns, flowing movement
        \li mixolydian
    \row
        \li \c desert
        \li Exotic, shimmering heat haze
        \li phrygian
    \row
        \li \c snow
        \li Crystalline, ethereal cold
        \li pentatonic
    \endtable

    \section1 Available Scales

    \list
    \li \c major - Bright, happy (Ionian mode)
    \li \c minor - Sad, melancholic (Aeolian mode)
    \li \c dorian - Mysterious, jazzy minor with raised 6th
    \li \c phrygian - Dark, Spanish/Middle Eastern flavor
    \li \c lydian - Dreamy, floating with raised 4th
    \li \c mixolydian - Bright but with flat 7th, folk-like
    \li \c pentatonic - Simple 5-note scale, Asian feel
    \li \c blues - Soulful with blue notes
    \endlist

    \section1 Layer Control

    Control which musical layers are active:
    \qml
    MoodPlayer {
        environment: "cave"
        layers: ["arp", "pad", "bass"]  // melody disabled for ambient feel
    }
    \endqml

    Available layers:
    \list
    \li \c arp - Rhythmic arpeggiated chords
    \li \c melody - Thematic melodic line
    \li \c pad - Sustained atmospheric drone
    \li \c bass - Low-frequency foundation
    \endlist

    \sa Sound, Music
*/
ChipMood {
    id: root
}
