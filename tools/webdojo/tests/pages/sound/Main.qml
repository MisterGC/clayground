// Regression page for MisterGC/clayground#216 - overlaid onto the starter
// bundle by wasm_smoke_test.py. Both halves of the freeze it guards against
// only ever showed up in a browser:
//
//   * constructing Music creates a QAudioOutput, which resolves the default
//     audio device;
//   * the first triggered note opens the shared QAudioSink, which asks for
//     the same device.
//
// On Qt 6.11 for WebAssembly that first device query deadlocked the page's
// main thread, so the page below either loads and prints its marker within
// seconds or the tab is frozen and the test times out.

import QtQuick
import Clayground.Sound

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    Music { id: music }
    SynthInstrument { id: synth }

    Text {
        anchors.centerIn: parent
        color: "#00d9ff"
        font.pixelSize: 24
        text: root.note
    }
    property string note: "creating audio objects"

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            synth.triggerNote(60, 0.5, 0.2)
            root.note = "audio device query returned"
            console.log("clay-sound: audio device query returned")
        }
    }
}
