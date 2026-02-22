// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtMultimedia

/*!
    \qmltype Music
    \inqmlmodule Clayground.Sound
    \inherits MediaPlayer
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
MediaPlayer {
    id: root

    /*!
        \qmlproperty real Music::volume
        \brief Playback volume from 0.0 (silent) to 1.0 (full).
    */
    property real volume: 1.0

    /*!
        \qmlproperty bool Music::lazyLoading
        \brief When true, the music is not loaded until load() or play() is called.

        On desktop this is a no-op (files load instantly). Effective on WASM
        where network fetching is involved.
    */
    property bool lazyLoading: false

    /*!
        \qmlproperty bool Music::loop
        \brief When true, the music loops after reaching the end.
    */
    property bool loop: false

    /*!
        \qmlproperty bool Music::loaded
        \brief True when the music data has been loaded and is ready to play.
    */
    readonly property bool loaded: mediaStatus === MediaPlayer.LoadedMedia
                                || mediaStatus === MediaPlayer.BufferedMedia

    /*!
        \qmlproperty bool Music::paused
        \brief True when the music is paused.
    */
    readonly property bool paused: playbackState === MediaPlayer.PausedState

    /*!
        \qmlproperty int Music::status
        \brief Loading status: 0=Null, 1=Loading, 2=Ready, 3=Error.
    */
    readonly property int status: {
        switch (mediaStatus) {
        case MediaPlayer.NoMedia:       return 0;
        case MediaPlayer.LoadingMedia:  return 1;
        case MediaPlayer.LoadedMedia:   return 2;
        case MediaPlayer.BufferedMedia: return 2;
        case MediaPlayer.EndOfMedia:    return 2;
        case MediaPlayer.InvalidMedia:  return 3;
        }
        return 0;
    }

    /*!
        \qmlsignal Music::finished()
        \brief Emitted when music playback reaches the end.
    */
    signal finished()

    /*!
        \qmlmethod void Music::seek(int ms)
        \brief Seek to the given position in milliseconds.
    */
    function seek(ms) {
        position = ms;
    }

    /*!
        \qmlmethod void Music::load()
        \brief Explicitly load the music data (useful with lazyLoading on WASM).
    */
    function load() {}

    loops: loop ? MediaPlayer.Infinite : 1
    audioOutput: AudioOutput {
        volume: root.volume
    }

    onMediaStatusChanged: {
        if (mediaStatus === MediaPlayer.EndOfMedia)
            finished();
    }
}
