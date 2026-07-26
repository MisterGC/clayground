// Connector3D demo - N orbiting satellites linked to a few hubs, drawn as a
// single instanced batch via ConnectorLayer3D. Move the slider up to 5000 and
// watch the draw-call count stay flat while the connectors track every frame.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

Item {
    id: rootItem
    anchors.fill: parent

    property var cameraStore: parent.cameraStore

    property real phase: 0
    property var sats: []
    // Per-hub satellite colors (Clayground palette).
    property var hubColors: ["#00d9ff", "#ff3366", "#ffd93d", "#0f9d9a"]

    Component.onCompleted: rebuild(1000)

    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    function rebuild(n) {
        var arr = new Array(n)
        var rng = makeRng(1337)
        var hubCount = hubList.length
        for (var i = 0; i < n; ++i) {
            arr[i] = {
                hub: i % hubCount,
                angle: rng() * 6.2831853,
                radius: 120 + rng() * 320,
                speed: 0.4 + rng() * 1.6,
                yoff: (rng() * 2 - 1) * 180
            }
        }
        rootItem.sats = arr
        rep.model = n
    }

    function orbit(i, ph) {
        var s = rootItem.sats[i]
        var c = hubList[s.hub].position
        var a = s.angle + ph * s.speed
        return Qt.vector3d(c.x + Math.cos(a) * s.radius,
                           c.y + Math.sin(a * 0.7) * s.radius * 0.5 + s.yoff,
                           c.z + Math.sin(a) * s.radius)
    }

    // Hub node lookup shared by the satellites.
    property var hubList: [hub0, hub1, hub2]

    View3D {
        id: view3D
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#0d0d1a"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: cam
            position: Qt.vector3d(0, 300, 1500)
            eulerRotation.x: -10
            clipFar: 40000

            Component.onCompleted: {
                if (cameraStore && cameraStore.has("connector_camPos"))
                    position = JSON.parse(cameraStore.get("connector_camPos"))
                if (cameraStore && cameraStore.has("connector_camRot"))
                    eulerRotation = JSON.parse(cameraStore.get("connector_camRot"))
            }
            Component.onDestruction: {
                if (cameraStore) {
                    cameraStore.set("connector_camPos", JSON.stringify(position))
                    cameraStore.set("connector_camRot", JSON.stringify(eulerRotation))
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

        // The three hubs the satellites connect to.
        Node {
            id: hub0
            position: Qt.vector3d(-500, 100, 0)
            Box3D { width: 40; height: 40; depth: 40; color: "#00d9ff" }
        }
        Node {
            id: hub1
            position: Qt.vector3d(500, 100, 0)
            Box3D { width: 40; height: 40; depth: 40; color: "#ff3366" }
        }
        Node {
            id: hub2
            position: Qt.vector3d(0, 150, -400)
            Box3D { width: 40; height: 40; depth: 40; color: "#ffd93d" }
        }

        // One batch for every connector -> a single draw call.
        ConnectorLayer3D {
            id: links
            viewportSize: Qt.vector2d(view3D.width, view3D.height)
            widthUnits: LineBatch3D.Pixel
            width: 1.5
            styles: [
                { dash: [0, 0], capRound: true, opacity: 0.9 },   // 0 solid
                { dash: [10, 8], capRound: false, opacity: 0.9 }  // 1 dashed
            ]
        }

        // Satellites: invisible transform carriers moved imperatively each
        // frame. Each owns one Connector3D targeting its hub.
        Repeater3D {
            id: rep
            model: 0
            delegate: Node {
                id: sat
                required property int index
                Connector3D {
                    layer: links
                    from: sat
                    to: rootItem.hubList[sat.index % rootItem.hubList.length]
                    color: rootItem.hubColors[sat.index % rootItem.hubList.length]
                    styleId: sat.index % 2
                }
            }
        }
    }

    // Drives satellite motion. Setting Node.position directly (no per-delegate
    // binding graph) keeps the scene cost low so the connector batch dominates.
    FrameAnimation {
        running: animSwitch.checked
        onTriggered: {
            rootItem.phase += 0.02
            var n = rep.count
            for (var i = 0; i < n; ++i) {
                var s = rep.objectAt(i)
                if (s)
                    s.position = rootItem.orbit(i, rootItem.phase)
            }
        }
    }

    DebugView {
        source: view3D
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
    }

    // Control panel.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        width: 260
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
                text: "Connector3D"
                color: "#00d9ff"
                font.pixelSize: 16
                font.bold: true
            }

            Text {
                text: "Connectors: " + links.count
                color: "#eaeaea"
                font.pixelSize: 12
            }

            Row {
                spacing: 6
                Repeater {
                    model: [ { label: "100", n: 100 },
                             { label: "1k", n: 1000 },
                             { label: "5k", n: 5000 } ]
                    Button {
                        text: modelData.label
                        width: 72
                        onClicked: rootItem.rebuild(modelData.n)
                    }
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
                    text: "Animate"
                    color: "#eaeaea"
                    font.pixelSize: 12
                }
            }
        }
    }

    // fps / draw-call readout.
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
            text: "Connectors: " + links.count + "\n" +
                  "FPS:         " + view3D.renderStats.fps + "\n" +
                  "Draw calls:  " + view3D.renderStats.drawCallCount
        }
    }
}
