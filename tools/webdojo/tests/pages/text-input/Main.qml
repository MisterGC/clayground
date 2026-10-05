// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for MisterGC/clayground#405 - overlaid onto the starter
// bundle by wasm_smoke_test.py --type. The single-window counterpart of
// text-input-window/: the runtime's own window holds the field, and typing
// into it has to keep working.

import QtQuick

Rectangle {
    anchors.fill: parent
    color: "#101018"

    MouseArea { anchors.fill: parent }

    Rectangle {
        x: 40; y: 40; width: 400; height: 48
        color: "#22ffffff"
        TextInput {
            anchors.fill: parent
            anchors.margins: 8
            color: "white"
            font.pixelSize: 24
            onTextChanged: console.log("TYPED:" + text)
        }
    }

    Component.onCompleted: console.log("text-input: ready")
}
