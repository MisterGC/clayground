// Performance Instrumentation - PerfHud + BenchLogger over an animated scene

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent

    // Access to camera store passed from parent
    property var cameraStore: parent.cameraStore

    environment: SceneEnvironment {
        clearColor: "#1a1a1a"
        backgroundMode: SceneEnvironment.Color
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 500, 900)
        eulerRotation.x: -28

        Component.onCompleted: {
            if (cameraStore && cameraStore.has("perf_camPos"))
                position = JSON.parse(cameraStore.get("perf_camPos"))
            if (cameraStore && cameraStore.has("perf_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("perf_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("perf_camPos", JSON.stringify(position))
                cameraStore.set("perf_camRot", JSON.stringify(eulerRotation))
            }
        }
    }

    WasdController {
        controlledObject: camera
        mouseEnabled: true
        keysEnabled: true
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
        castsShadow: true
        shadowFactor: 78
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
        pcfFactor: 2
        shadowBias: 18
        csmNumSplits: 3
    }

    // Animated load: a grid of rotating toon-shaded boxes to give the
    // instrumentation something non-trivial to measure.
    property int gridSide: 8
    property int boxCount: gridSide * gridSide

    Repeater3D {
        id: boxes
        model: view3D.boxCount

        Node {
            property int col: index % view3D.gridSide
            property int row: Math.floor(index / view3D.gridSide)
            x: (col - (view3D.gridSide - 1) / 2) * 120
            z: (row - (view3D.gridSide - 1) / 2) * 120

            Box3D {
                width: 70
                height: 70
                depth: 70
                color: Qt.hsva((index / view3D.boxCount), 0.6, 0.9, 1.0)
                edgeColorFactor: 2.0
                edgeThickness: 6
                useToonShading: true

                SequentialAnimation on eulerRotation {
                    loops: Animation.Infinite
                    PropertyAnimation {
                        from: Qt.vector3d(0, index * 6, 0)
                        to: Qt.vector3d(0, 360 + index * 6, 0)
                        duration: 3000 + (index % 7) * 400
                    }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    NumberAnimation { to: 60; duration: 1200 + (index % 5) * 200; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 0; duration: 1200 + (index % 5) * 200; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // Live overlay HUD.
    PerfHud {
        id: hud
        view3D: view3D
        extended: extendedToggle.checked
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
    }

    // CSV benchmark logger.
    BenchLogger {
        id: bench
        view3D: view3D
        outputPath: "/tmp/clay_canvas3d_bench.csv"
        intervalMs: 250
        extra: ({ "boxes": function() { return view3D.boxCount } })
        running: logToggle.checked
        onSampleTaken: sampleCount += 1
        property int sampleCount: 0
    }

    // Controls.
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Canvas3D Performance Demo"
            color: "white"
            font.pixelSize: 14
            font.bold: true
        }

        CheckBox {
            id: extendedToggle
            text: "Extended HUD (DebugView)"
            checked: false
            contentItem: Text {
                text: extendedToggle.text
                color: "white"
                leftPadding: extendedToggle.indicator.width + 6
                verticalAlignment: Text.AlignVCenter
            }
        }

        CheckBox {
            id: logToggle
            text: "Log to " + bench.outputPath
            checked: false
            contentItem: Text {
                text: logToggle.text
                color: "white"
                leftPadding: logToggle.indicator.width + 6
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            text: "Samples written: " + bench.sampleCount
            color: "#ffd93d"
            font.pixelSize: 12
        }
    }
}
