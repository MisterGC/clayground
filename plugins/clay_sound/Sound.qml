// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Sound
    \inqmlmodule Clayground.Sound
    \inherits ClaySound
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
ClaySound {
    // The C++ ClaySound class provides all functionality
    // This QML wrapper adds documentation and allows future extensions
}
