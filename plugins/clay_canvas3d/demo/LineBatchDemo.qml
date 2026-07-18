// LineBatch3D demo - 100k+ styled polylines in a single instanced draw call.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

Item {
    id: rootItem
    anchors.fill: parent

    property var cameraStore: parent.cameraStore

    // Clayground palette (rgb bytes) used for random per-line colors.
    property var linePalette: [
        [0, 217, 255],   // cyan
        [15, 157, 154],  // teal
        [255, 51, 102],  // pink
        [255, 217, 61]   // gold
    ]

    property int animatedCount: 30
    property var animBase: []
    property real animTime: 0

    Component.onCompleted: regenerate(1000)

    // Verification helper: current batch and render statistics.
    function stats() {
        return {
            lines: batch.count,
            fps: view3D.renderStats.fps,
            drawCalls: view3D.renderStats.drawCallCount,
            vertices: view3D.renderStats.drawVertexCount
        }
    }

    function regenerate(n) {
        var animN = Math.min(rootItem.animatedCount, n)

        // First pass: segment counts and total point count.
        var segCounts = new Array(n)
        var totalPoints = 0
        for (var i = 0; i < n; ++i) {
            var s = (i < animN) ? 4 : (3 + Math.floor(Math.random() * 4)) // 3..6 segments
            segCounts[i] = s
            totalPoints += s + 1
        }

        var positions = new Float32Array(totalPoints * 3)
        var starts = new Uint32Array(n + 1)
        var colors = new Uint8Array(n * 4)
        var widths = new Float32Array(n)

        var newAnim = []
        var pIdx = 0
        for (i = 0; i < n; ++i) {
            starts[i] = pIdx
            var seg = segCounts[i]
            var ox = (Math.random() * 2 - 1) * 2000
            var oy = Math.random() * 400
            var oz = (Math.random() * 2 - 1) * 2000
            var cx = ox, cy = oy, cz = oz
            var linePts = []
            for (var j = 0; j <= seg; ++j) {
                positions[pIdx * 3 + 0] = cx
                positions[pIdx * 3 + 1] = cy
                positions[pIdx * 3 + 2] = cz
                linePts.push([cx, cy, cz])
                pIdx++
                cx += (Math.random() * 2 - 1) * 130
                cy += (Math.random() * 2 - 1) * 130
                cz += (Math.random() * 2 - 1) * 130
            }
            var c = rootItem.linePalette[Math.floor(Math.random() * rootItem.linePalette.length)]
            colors[i * 4 + 0] = c[0]
            colors[i * 4 + 1] = c[1]
            colors[i * 4 + 2] = c[2]
            colors[i * 4 + 3] = 255
            widths[i] = 1.0 + Math.random() * 5.0
            if (i < animN)
                newAnim.push({ base: linePts, phase: Math.random() * Math.PI * 2, seg: seg })
        }
        starts[n] = pIdx

        batch.setBulk(positions.buffer, starts.buffer, colors.buffer, widths.buffer)
        rootItem.animBase = newAnim
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#12121c"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: cam
            position: Qt.vector3d(0, 900, 2600)
            eulerRotation.x: -18
            clipFar: 40000

            Component.onCompleted: {
                if (cameraStore && cameraStore.has("linebatch_camPos"))
                    position = JSON.parse(cameraStore.get("linebatch_camPos"))
                if (cameraStore && cameraStore.has("linebatch_camRot"))
                    eulerRotation = JSON.parse(cameraStore.get("linebatch_camRot"))
            }
            Component.onDestruction: {
                if (cameraStore) {
                    cameraStore.set("linebatch_camPos", JSON.stringify(position))
                    cameraStore.set("linebatch_camRot", JSON.stringify(eulerRotation))
                }
            }
        }

        WasdController {
            controlledObject: cam
            mouseEnabled: true
            keysEnabled: true
        }

        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -60
        }

        LineBatch3D {
            id: batch
            viewportSize: Qt.vector2d(view3D.width, view3D.height)
            widthUnits: widthSwitch.checked ? LineBatch3D.World : LineBatch3D.Pixel
            depthBias: 0
        }

        // Styled showcase: a stack of horizontal lines mixing solid, dashed,
        // dotted and translucent styles at various widths. Style rows are baked
        // into the batch's style table; each line selects a row via styleId.
        LineBatch3D {
            id: styledBatch
            viewportSize: Qt.vector2d(view3D.width, view3D.height)
            widthUnits: LineBatch3D.World
            depthBias: 2
            visible: styledSwitch.checked
            styles: [
                { dash: [0, 0],   capRound: true,  opacity: 1.0 },  // 0 solid
                { dash: [55, 35], capRound: false, opacity: 1.0 },  // 1 dashed
                { dash: [6, 34],  capRound: true,  opacity: 1.0 },  // 2 dotted
                { dash: [0, 0],   capRound: true,  opacity: 0.35 }  // 3 translucent
            ]
            lines: [
                { points: [Qt.vector3d(-600, 780, 0), Qt.vector3d(600, 780, 0)], color: "#00d9ff", width: 8,  styleId: 0 },
                { points: [Qt.vector3d(-600, 700, 0), Qt.vector3d(600, 700, 0)], color: "#0f9d9a", width: 14, styleId: 1 },
                { points: [Qt.vector3d(-600, 620, 0), Qt.vector3d(600, 620, 0)], color: "#ff3366", width: 10, styleId: 2 },
                { points: [Qt.vector3d(-600, 540, 0), Qt.vector3d(600, 540, 0)], color: "#ffd93d", width: 22, styleId: 1 },
                { points: [Qt.vector3d(-600, 460, 0), Qt.vector3d(600, 460, 0)], color: "#00d9ff", width: 28, styleId: 3 },
                { points: [Qt.vector3d(-600, 380, 0), Qt.vector3d(600, 380, 0)], color: "#ffffff", width: 6,  styleId: 2 }
            ]
        }
    }

    // Forces extended render-stat collection (drawCallCount / drawVertexCount)
    // and mirrors the numbers for cross-checking the Text readout below.
    DebugView {
        source: view3D
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        visible: debugSwitch.checked
    }

    Timer {
        interval: 16
        running: animSwitch.checked
        repeat: true
        onTriggered: {
            rootItem.animTime += 0.05
            var arr = rootItem.animBase
            for (var k = 0; k < arr.length; ++k) {
                var a = arr[k]
                var pts = []
                for (var j = 0; j <= a.seg; ++j) {
                    var bp = a.base[j]
                    var ph = a.phase + j * 0.6 + rootItem.animTime
                    pts.push(Qt.vector3d(bp[0] + Math.sin(ph) * 90,
                                         bp[1] + Math.cos(ph) * 90,
                                         bp[2] + Math.sin(ph * 0.5) * 90))
                }
                batch.updateLinePoints(k, pts)
            }
        }
    }

    // Control panel.
    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        width: 240
        height: panelCol.implicitHeight + 24
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        border.width: 1

        Column {
            id: panelCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "LineBatch3D"
                color: "#00d9ff"
                font.pixelSize: 16
                font.bold: true
            }

            Text {
                text: "Line count"
                color: "#eaeaea"
                font.pixelSize: 12
            }

            Row {
                spacing: 6
                Repeater {
                    model: [ { label: "1k", n: 1000 },
                             { label: "10k", n: 10000 },
                             { label: "100k", n: 100000 } ]
                    Button {
                        text: modelData.label
                        width: 66
                        onClicked: rootItem.regenerate(modelData.n)
                    }
                }
            }

            Row {
                spacing: 8
                Switch {
                    id: widthSwitch
                    checked: false
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: widthSwitch.checked ? "World width" : "Pixel width"
                    color: "#eaeaea"
                    font.pixelSize: 12
                }
            }

            Row {
                spacing: 8
                Switch {
                    id: animSwitch
                    checked: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Animate subset (" + rootItem.animBase.length + " lines)"
                    color: "#eaeaea"
                    font.pixelSize: 12
                }
            }

            Row {
                spacing: 8
                Switch {
                    id: styledSwitch
                    checked: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Styled showcase"
                    color: "#eaeaea"
                    font.pixelSize: 12
                }
            }

            Row {
                spacing: 8
                Switch {
                    id: debugSwitch
                    checked: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DebugView"
                    color: "#eaeaea"
                    font.pixelSize: 12
                }
            }
        }
    }

    // renderStats readout.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: statsText.implicitWidth + 24
        height: statsText.implicitHeight + 20
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        border.width: 1

        Text {
            id: statsText
            anchors.centerIn: parent
            color: "#00d9ff"
            font.family: "Menlo"
            font.pixelSize: 13
            text: "Lines:       " + batch.count + "\n" +
                  "FPS:         " + view3D.renderStats.fps + "\n" +
                  "Draw calls:  " + view3D.renderStats.drawCallCount + "\n" +
                  "Vertices:    " + view3D.renderStats.drawVertexCount
        }
    }
}
