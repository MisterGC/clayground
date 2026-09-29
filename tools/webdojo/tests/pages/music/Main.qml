// Regression page for MisterGC/clayground#261 - overlaid onto the starter
// bundle by wasm_smoke_test.py. The appshell loads Main.qml over http, so
// `source: "track.mp3"` becomes an http URL - the case that took the page
// down: Qt's WASM media backend routed a non-local URL to its video output,
// which has no element unless a video sink was attached, and reading
// position off that missing element threw "Cannot read properties of
// undefined (reading 'currentTime')" before Main.qml even finished loading.
//
// Binding `position` is therefore part of the test, not decoration. The
// marker comes from onFinished, so it only appears if the browser really
// fetched, decoded and played the ~1.9 s clip; the run needs --click,
// without a user gesture no browser plays audio at all.

import QtQuick
import Clayground.Sound

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    property string note: "creating Music"

    Music {
        id: music
        source: "track.mp3"
        volume: 0.2
        onFinished: {
            root.note = "played to the end"
            console.log("clay-sound: music played to the end on the web")
        }
    }

    Text {
        anchors.centerIn: parent
        color: "#00d9ff"
        font.pixelSize: 24
        text: root.note + " - " + music.position + "/" + music.duration + " ms"
    }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            music.play()
            root.note = "play() returned"
        }
    }

    // Heartbeat: tells a frozen page apart from one that is merely waiting.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: console.log("clay-sound: alive, status=" + music.status
                                 + " playing=" + music.playing)
    }
}
