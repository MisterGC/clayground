// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Music
    \inqmlmodule Clayground.Sound
    \inherits ClayMusic
    \brief Play background music with play/pause/stop/loop controls.

    Music provides an interface for playing longer audio tracks like
    background music. Supports play, pause, stop, seek, and looping.

    Example usage:
    \qml
    import Clayground.Sound

    Music {
        id: bgMusic
        source: "music/theme.mp3"
        volume: 0.5
        loop: true
    }

    // In game logic:
    onGameStarted: bgMusic.play()
    onGamePaused: bgMusic.pause()
    onGameOver: bgMusic.stop()
    \endqml

    For short sound effects, use Sound instead.

    \sa Sound
*/
ClayMusic {
    // The C++ ClayMusic class provides all functionality
    // This QML wrapper adds documentation and allows future extensions
}
