// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype MusicMonitor
    \inqmlmodule Clayground.Sound
    \inherits ClayMusicMonitor
    \brief Real-time audio spectrum and level analysis for Music components.

    MusicMonitor taps into a \l Music component's audio output and provides
    real-time frequency spectrum data and an RMS audio level. Useful for
    visualizers, VU meters, and beat detection.

    Example usage:
    \qml
    import Clayground.Sound

    Music {
        id: bgMusic
        source: "music/theme.mp3"
    }

    MusicMonitor {
        id: monitor
        music: bgMusic
        fftSize: 256         // 128 frequency bins
        updateInterval: 33   // ~30 fps
    }

    // Use monitor.spectrum (list<real>) and monitor.level (real)
    \endqml

    \sa Music
*/
ClayMusicMonitor {
}
