// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for the plugin shaders on the web (#330, found by
// MisterGC/shapes-and-stone#40) - overlaid onto the starter bundle by
// wasm_smoke_test.py. WebGL2's vertex shaders are GLSL 300 es, and a
// fragment shader of another version does not link: clay_world baked its
// four without 300 es, so the world drew nothing but what lay beside it and
// the console filled with "Failed to link shader program". The harness fails
// on that line.
//
// Every ShaderEffect clay_world ships is on screen here and active: the
// light layer, the screen overlay (vignette) and grade (tint), and the
// anchored mask. The marker comes once they have drawn for a while.

import QtQuick
import Clayground.World

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    ClayWorld2d {
        id: world
        anchors.fill: parent
        components: new Map()
        xWuMax: 40; yWuMax: 30
        pixelPerUnit: 20
        gravity: Qt.point(0, 0)
        viewPortCenterWuX: 20
        viewPortCenterWuY: 15

        Rectangle {
            parent: world.room
            x: 340; y: 200
            width: 80; height: 80
            color: "#6a6a80"
        }

        LightLayer2d { world: world; ambient: "#181820" }
        Light2d { xWu: 14; yWu: 15; radius: 10; color: "#ffb060" }
        Light2d { xWu: 26; yWu: 12; radius: 8; color: "#60b0ff" }

        ScreenFx2d {
            world: world
            vignette: 0.6
            tint: "#ffe0c0"
        }

        AnchoredMask { world: world; target: spot }
    }

    QtObject { id: spot; property real xWu: 20; property real yWu: 15 }

    Timer {
        interval: 2000
        running: true
        onTriggered: console.log("world-fx: drawn")
    }
}
