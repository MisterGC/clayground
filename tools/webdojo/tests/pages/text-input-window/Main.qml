// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for MisterGC/clayground#405 - overlaid onto the starter
// bundle by wasm_smoke_test.py --type. A game whose root is a Window has a
// second Qt window next to the runtime's own, which is then 0x0. The
// full-window MouseArea is what makes a click on the field lose: Qt does not
// take the pointerdown, the browser's mousedown moves focus to <body>, and
// the page used to give focus back to the 0x0 window's input, which cannot
// take it - the field had Qt's focus and got no key.

import QtQuick

Window {
    id: root
    visible: true
    visibility: Window.Maximized
    // without it the browser draws a title bar over the top of the window
    flags: Qt.FramelessWindowHint
    color: "#101018"

    property bool ready: false
    onFrameSwapped: if (!ready) { ready = true; console.log("text-input: ready") }

    MouseArea { anchors.fill: parent }

    Rectangle {
        x: 40; y: 40; width: 400; height: 48
        color: "#22ffffff"
        TextInput {
            id: field
            anchors.fill: parent
            anchors.margins: 8
            color: "white"
            font.pixelSize: 24
            onTextChanged: console.log("TYPED:" + text)
        }
    }
}
