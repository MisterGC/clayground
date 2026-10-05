// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for MisterGC/clayground#341 - overlaid onto the starter
// bundle by wasm_smoke_test.py --reload-expect. KeyValueStore used to write
// its SQLite file into Emscripten's in-memory file system only, so a value
// stored on the web was gone after a page reload.
//
// The first load finds nothing, stores a token and says so; the harness then
// reloads the page, and the second load must find the token again.

import QtQuick
import Clayground.Storage

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    property string status: ""

    KeyValueStore { id: store; name: "clay-storage-reload-gate" }

    Text {
        anchors.centerIn: parent
        color: "#00d9ff"
        font.pixelSize: 24
        text: root.status
    }

    Component.onCompleted: {
        if (store.has("token")) {
            status = "clay-storage: read back " + store.get("token", "")
        } else {
            const token = "t" + Date.now()
            store.set("token", token)
            status = "clay-storage: wrote " + token
        }
        console.log(status)
    }
}
