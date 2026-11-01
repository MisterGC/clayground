// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for MisterGC/clayground#480 - overlaid onto the starter
// bundle by wasm_smoke_test.py. The page plays from the moment it loads,
// the way a title tune does, and the player's first click comes after that.
// The browser holds back an AudioContext created before any click, and the
// click on Qt's window never reached emscripten's own resume listeners, so
// the page stayed silent for good. wasm_smoke_test.py --click-after clicks
// once the notes are under way and --require-audible after-click listens
// to the page's audio graph after that click.

import QtQuick
import Clayground.Sound

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    // For its constructor: Qt enumerates the browser's audio devices, each
    // through an AudioContext of its own, before any click.
    Music { id: music }
    SynthInstrument { id: synth }

    property int notes: 0
    property bool clicked: false

    Text {
        anchors.centerIn: parent
        color: "#00d9ff"
        font.pixelSize: 24
        text: root.clicked ? "clicked" : "playing - click"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.clicked) return
            root.clicked = true
            console.log("PHASE:after-click")
            listened.start()
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            synth.triggerNote(60 + root.notes % 12, 0.8, 0.12)
            root.notes++
            if (root.notes === 8) {
                console.log("PHASE:before-click")
                console.log("clay-sound: notes started before a click")
            }
        }
    }

    Timer {
        id: listened
        interval: 3000
        onTriggered: console.log("clay-sound: listened after the click")
    }
}
