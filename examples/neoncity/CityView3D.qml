// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Synthwave city viewport: a dusk gradient backdrop behind a transparent
// View3D, toon-lit streamed tiles, depth fog to melt distant tiles into the
// horizon, a fly camera and an overview toggle, plus the perf/info HUD.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

Item {
    id: root
    anchors.fill: parent
    focus: true

    // ---- settable from the Sandbox ----
    property int globalSeed: 42
    property real tileSize: 200
    property int streamRadius: 2
    property bool perfHud: false

    // ---- live readouts (mirrored from the streaming manager) ----
    readonly property int currentTileX: tileManager.currentTileX
    readonly property int currentTileZ: tileManager.currentTileZ
    readonly property int loadedCount: tileManager.loadedCount
    readonly property int buildingCount: tileManager.buildingCount

    // Render metrics (bound for trace-based benchmarking).
    readonly property real perfFps: view.renderStats.fps
    readonly property real perfFrameMs: view.renderStats.frameTime
    readonly property int perfDraws: view.renderStats.drawCallCount
    readonly property int perfVerts: view.renderStats.drawVertexCount

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    property bool overview: false
    property bool benchmark: false

    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_P) { root.perfHud = !root.perfHud; e.accepted = true }
        else if (e.key === Qt.Key_O) { root.toggleOverview(); e.accepted = true }
    }

    // Places the fly camera at street level over a given tile (demo/verification aid).
    function jumpTo(tx, tz) {
        overview = false
        camera.position = Qt.vector3d(tx * tileSize + tileSize * 0.5,
                                      tileSize * 0.42,
                                      tz * tileSize + tileSize * 1.35)
        camera.eulerRotation = Qt.vector3d(-16, 0, 0)
    }

    function toggleOverview() {
        overview = !overview
        if (overview) {
            camera.position = Qt.vector3d(tileManager.currentTileX * tileSize + tileSize * 0.5,
                                          tileSize * 6.5,
                                          tileManager.currentTileZ * tileSize + tileSize * 3.0)
            camera.eulerRotation = Qt.vector3d(-62, 0, 0)
        } else {
            camera.position = Qt.vector3d(tileManager.currentTileX * tileSize + tileSize * 0.5,
                                          tileSize * 0.42,
                                          tileManager.currentTileZ * tileSize + tileSize * 1.35)
            camera.eulerRotation = Qt.vector3d(-16, 0, 0)
        }
    }

    // ---- dusk gradient backdrop (behind the transparent View3D) ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#140a24" }
            GradientStop { position: 0.52; color: "#3d1a54" }
            GradientStop { position: 0.70; color: "#c02a6e" }
            GradientStop { position: 0.80; color: "#43122f" }
            GradientStop { position: 1.0; color: "#0a0a16" }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (m) => { root.forceActiveFocus(); m.accepted = false }
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: camera

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            fog: Fog {
                enabled: true
                color: "#5a1e5c"
                density: 0.9
                depthEnabled: true
                depthNear: root.tileSize * 2.0
                depthFar: root.tileSize * 7.5
            }
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(root.tileSize * 0.5, root.tileSize * 0.42, root.tileSize * 1.35)
            eulerRotation.x: -16
            clipFar: 24000
            fieldOfView: 65
        }

        WasdController {
            controlledObject: camera
            mouseEnabled: true
            keysEnabled: true
            forwardSpeed: 3.0
            backSpeed: 3.0
            leftSpeed: 3.0
            rightSpeed: 3.0
        }

        // Toon key light (matches the Canvas3D demos).
        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -60
            color: Qt.rgba(1.0, 0.92, 0.98, 1.0)
            brightness: 0.85
            ambientColor: Qt.rgba(0.22, 0.20, 0.32, 1.0)
            castsShadow: true
            shadowFactor: 78
            shadowMapQuality: Light.ShadowMapQualityHigh
            csmNumSplits: 2
            pcfFactor: 2
            shadowBias: 12
        }

        // Cool fill from the pink horizon side.
        DirectionalLight {
            eulerRotation.x: -12
            eulerRotation.y: 130
            color: "#ff3366"
            brightness: 0.18
            castsShadow: false
        }

        // Continuous camera yaw used only for perf measurement: forces the
        // View3D to render every frame so renderStats reflect real cost.
        NumberAnimation {
            target: camera
            property: "eulerRotation.y"
            from: 0; to: 360
            duration: 9000
            loops: Animation.Infinite
            running: root.benchmark
        }

        TileManager {
            id: tileManager
            camera: camera
            tileSize: root.tileSize
            globalSeed: root.globalSeed
            streamRadius: root.streamRadius
        }
    }

    // ---- perf overlay ----
    PerfHud {
        view3D: view
        extended: false
        visible: root.perfHud
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
    }

    // ---- info HUD ----
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: infoCol.implicitWidth + 24
        height: infoCol.implicitHeight + 18
        radius: 8
        color: Qt.rgba(0.05, 0.06, 0.10, 0.82)
        border.color: "#0f9d9a"
        border.width: 1

        Column {
            id: infoCol
            x: 12
            y: 9
            spacing: 3

            Text {
                text: "NEON CITY"
                color: "#00d9ff"
                font.family: root.monoFont
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                text: "seed " + root.globalSeed + "   tile " +
                      tileManager.currentTileX + "," + tileManager.currentTileZ
                color: "#eaeaea"
                font.family: root.monoFont
                font.pixelSize: 12
            }
            Text {
                text: "tiles " + tileManager.loadedCount +
                      "   buildings " + tileManager.buildingCount
                color: "#ffd93d"
                font.family: root.monoFont
                font.pixelSize: 12
            }
            Text {
                text: "WASD+drag fly   O overview   P perf"
                color: "#8a8a9a"
                font.family: root.monoFont
                font.pixelSize: 11
            }
        }
    }
}
