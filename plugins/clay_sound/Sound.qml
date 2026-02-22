// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtMultimedia

/*!
    \qmltype Sound
    \inqmlmodule Clayground.Sound
    \inherits SoundEffect
    \brief Play sound effects with support for overlapping playback.

    Sound provides an easy-to-use interface for playing short sound effects
    like jump sounds, clicks, explosions, etc. Multiple instances of the same
    sound can play simultaneously (overlapping).

    Example usage:
    \qml
    import Clayground.Sound

    Sound {
        id: jumpSound
        source: "sounds/jump.wav"
        volume: 0.8
    }

    // In game logic:
    onJumped: jumpSound.play()
    \endqml

    For background music with play/pause/stop/loop, use Music instead.

    \sa Music
*/
SoundEffect {
    id: root

    /*!
        \qmlproperty bool Sound::lazyLoading
        \brief When true, the sound is not loaded until load() or play() is called.

        On desktop this is a no-op (files load instantly). Effective on WASM
        where network fetching is involved.
    */
    property bool lazyLoading: false

    /*!
        \qmlproperty bool Sound::loaded
        \brief True when the sound data has been fully loaded and is ready to play.
    */
    readonly property bool loaded: status === SoundEffect.Ready

    /*!
        \qmlsignal Sound::finished()
        \brief Emitted when a sound effect finishes playing.
    */
    signal finished()

    /*!
        \qmlsignal Sound::errorOccurred(string message)
        \brief Emitted when an error occurs during loading or playback.
    */
    signal errorOccurred(string message)

    /*!
        \qmlmethod void Sound::load()
        \brief Explicitly load the sound data (useful with lazyLoading on WASM).
    */
    function load() {}

    onPlayingChanged: {
        if (!playing)
            finished();
    }
    onStatusChanged: {
        if (status === SoundEffect.Error)
            errorOccurred("Failed to load sound: " + source);
    }
}
