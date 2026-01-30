// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype MoodPlayer
    \inqmlmodule Clayground.Sound
    \inherits ChipMood
    \brief SNES-style atmospheric music generator.

    MoodPlayer creates procedural atmospheric music inspired by classic SNES RPG
    soundtracks like Chrono Trigger, Secret of Mana, and Zelda: A Link to the Past.

    It uses Web Audio API synthesis with square, triangle, and sine wave oscillators,
    low-pass filtering for SNES "warmth", and echo/delay for the signature SNES reverb.

    \qml
    import Clayground.Sound

    MoodPlayer {
        id: music
        mood: "mysterious_forest"
        volume: 0.7
        intensity: 0.5
        onReadyChanged: if (ready) play()
    }
    \endqml

    Available moods:
    \list
    \li \c mysterious_forest - Dorian mode, ethereal arpeggios (Secret of the Forest style)
    \li \c dark_dungeon - Phrygian mode, tense atmosphere (Dark World style)
    \li \c peaceful_village - Major mode, light and peaceful (Kakariko Village style)
    \endlist

    \sa Sound, Music
*/
ChipMood {
    id: root
}
