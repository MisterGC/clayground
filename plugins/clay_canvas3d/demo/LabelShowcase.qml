// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Label3D gallery: anchored tracking, screen/world sizing, leaders, readability
// @tags 3D, Canvas3D, Labels
// @category Plugin Demos
//
// Living reference and verification page for Label3D callout labels. Standalone:
//   clayliveloader --sbx LabelShowcase.qml
// Drive the camera via the inspector: set root.camDist / orbitYaw / orbitPitch
// or applyScenario(name); flagInfo() reports the live registry count and camera.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Canvas3D

Item {
    id: root
    anchors.fill: parent

    // --- inspector-writable camera controls ---
    property real camDist: 950
    property real orbitYaw: 0
    property real orbitPitch: -22
    property bool playing: true

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Drives the patrol drone; the anchored label tracks it every frame.
    property real t: 0
    FrameAnimation {
        running: root.playing
        onTriggered: root.t = elapsedTime
    }

    // The ~12-label back row: name + palette color, laid out along X at z=-450.
    readonly property var rowLabels: [
        { txt: "N01", c: "#00d9ff" }, { txt: "N02", c: "#0f9d9a" },
        { txt: "N03", c: "#ff3366" }, { txt: "N04", c: "#ffd93d" },
        { txt: "N05", c: "#00d9ff" }, { txt: "N06", c: "#0f9d9a" },
        { txt: "N07", c: "#ff3366" }, { txt: "N08", c: "#ffd93d" },
        { txt: "N09", c: "#00d9ff" }, { txt: "N10", c: "#0f9d9a" },
        { txt: "N11", c: "#ff3366" }, { txt: "N12", c: "#ffd93d" }
    ]
    function rowX(i) { return (i - (root.rowLabels.length - 1) / 2) * 100 }

    // ---- inspector helpers ----
    function flagInfo() {
        return {
            camDist: root.camDist,
            orbitYaw: root.orbitYaw,
            orbitPitch: root.orbitPitch,
            playing: root.playing,
            // Proves the per-view registry hook: every Label3D self-registered.
            registered: Label3DRegistry.labelsFor(view).length,
            fps: view.renderStats ? view.renderStats.fps : -1
        }
    }

    function scenarios() {
        return ["overview", "angled", "near", "far", "readability", "leader"]
    }

    function applyScenario(name) {
        switch (name) {
        case "overview":    root.camDist = 950;  root.orbitYaw = 0;   root.orbitPitch = -22; break
        case "angled":      root.camDist = 950;  root.orbitYaw = 38;  root.orbitPitch = -28; break
        case "near":        root.camDist = 480;  root.orbitYaw = 0;   root.orbitPitch = -14; break
        case "far":         root.camDist = 1800; root.orbitYaw = 0;   root.orbitPitch = -14; break
        case "readability": root.camDist = 620;  root.orbitYaw = -30; root.orbitPitch = -10; break
        case "leader":      root.camDist = 620;  root.orbitYaw = 0;   root.orbitPitch = -16; break
        }
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#12121c"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // Orbit rig: yaw pivot -> pitch pivot -> camera at local +Z, looking at
        // the origin. Repositioning it (inspector) exercises the billboard path.
        Node {
            eulerRotation.y: root.orbitYaw
            Node {
                eulerRotation.x: root.orbitPitch
                PerspectiveCamera {
                    id: cam
                    position: Qt.vector3d(0, 0, root.camDist)
                    clipFar: 20000
                    clipNear: 1
                }
            }
        }

        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -30
        }

        // Ground plane for depth cue.
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(20, 12, 1)
            materials: PrincipledMaterial { baseColor: "#161a2b"; lighting: PrincipledMaterial.NoLighting }
        }

        // ===== readability: labels over a bright and a dark backdrop =====
        Model {
            source: "#Rectangle"; x: -560; y: 150; z: -120
            scale: Qt.vector3d(2.6, 1.6, 1)
            materials: PrincipledMaterial { baseColor: "#f2f2f2"; lighting: PrincipledMaterial.NoLighting }
        }
        Model {
            source: "#Rectangle"; x: -300; y: 150; z: -120
            scale: Qt.vector3d(2.6, 1.6, 1)
            materials: PrincipledMaterial { baseColor: "#050608"; lighting: PrincipledMaterial.NoLighting }
        }
        Label3D {
            view: view; camera: cam
            anchorPosition: Qt.vector3d(-560, 150, -120)
            // In front of the patch so billboard rotation never dips the pill
            // behind the opaque backdrop.
            labelOffset: Qt.vector3d(0, 0, 90)
            text: "BRIGHT BG"
        }
        Label3D {
            view: view; camera: cam
            anchorPosition: Qt.vector3d(-300, 150, -120)
            labelOffset: Qt.vector3d(0, 0, 90)
            text: "DARK BG"
        }

        // ===== moving entity: a patrol drone the label tracks =====
        Node {
            id: drone
            x: -60 + Math.cos(root.t * 0.6) * 140
            y: 60
            z: 60 + Math.sin(root.t * 0.6) * 90
            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.35, 0.35, 0.35)
                materials: PrincipledMaterial { baseColor: "#0f9d9a" }
            }
        }
        Label3D {
            view: view; camera: cam
            anchorNode: drone
            labelOffset: Qt.vector3d(0, 55, 0)
            text: "PATROL DRONE"
            labelStyle.borderColor: "#0f9d9a"
        }

        // ===== static-position beacon label (no leader) =====
        Model {
            source: "#Cube"; x: 40; y: 20; z: 240
            scale: Qt.vector3d(0.25, 0.25, 0.25)
            materials: PrincipledMaterial { baseColor: "#ff3366" }
        }
        Label3D {
            view: view; camera: cam
            anchorPosition: Qt.vector3d(40, 20, 240)
            labelOffset: Qt.vector3d(0, 55, 0)
            text: "ORIGIN BEACON"
            labelStyle.borderColor: "#ff3366"
        }

        // ===== leader-line callout offset from a small object =====
        Model {
            source: "#Sphere"; x: 300; y: 25; z: 150
            scale: Qt.vector3d(0.3, 0.3, 0.3)
            materials: PrincipledMaterial { baseColor: "#ffd93d" }
        }
        Label3D {
            view: view; camera: cam
            anchorPosition: Qt.vector3d(300, 25, 150)
            labelOffset: Qt.vector3d(-120, 150, 0)
            text: "SENSOR MAST"
            showLeader: true
            leaderStyle.color: "#ffd93d"
            leaderStyle.width: 2
            labelStyle.borderColor: "#ffd93d"
        }

        // ===== Screen vs World size mode, side by side =====
        Model {
            source: "#Cylinder"; x: 520; y: 40; z: -40
            scale: Qt.vector3d(0.2, 0.8, 0.2)
            materials: PrincipledMaterial { baseColor: "#00d9ff" }
        }
        Label3D {
            view: view; camera: cam
            anchorPosition: Qt.vector3d(520, 90, -40)
            labelOffset: Qt.vector3d(0, 30, 0)
            sizeMode: Label3D.Screen
            text: "SCREEN"
            labelStyle.borderColor: "#00d9ff"
        }
        Model {
            source: "#Cylinder"; x: 700; y: 40; z: -40
            scale: Qt.vector3d(0.2, 0.8, 0.2)
            materials: PrincipledMaterial { baseColor: "#ffd93d" }
        }
        Label3D {
            view: view; camera: cam
            anchorPosition: Qt.vector3d(700, 90, -40)
            labelOffset: Qt.vector3d(0, 30, 0)
            sizeMode: Label3D.World
            worldHeight: 34
            text: "WORLD"
            labelStyle.borderColor: "#ffd93d"
        }

        // ===== ~12-label front row: multi-label stability =====
        Repeater3D {
            model: root.rowLabels
            delegate: Label3D {
                id: rowCell
                required property int index
                required property var modelData
                view: view
                camera: cam
                anchorPosition: Qt.vector3d(root.rowX(index), 25, 80)
                labelOffset: Qt.vector3d(0, 0, 0)
                text: rowCell.modelData.txt
                labelStyle.borderColor: rowCell.modelData.c
                labelStyle.fontSize: 18
            }
        }
    }

    // ---- control panel (style mirrors LineStylesShowcase) ----
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        width: panelCol.implicitWidth + 24
        height: panelCol.implicitHeight + 24
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        border.width: 1

        Column {
            id: panelCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Text {
                text: "Label3D showcase"
                color: "#00d9ff"
                font.pixelSize: 15
                font.bold: true
                font.family: root.monoFont
            }
            Text {
                text: "camDist " + root.camDist.toFixed(0) +
                      "  yaw " + root.orbitYaw.toFixed(0) +
                      "  pitch " + root.orbitPitch.toFixed(0)
                color: "#eaeaea"
                font.pixelSize: 12
                font.family: root.monoFont
            }
            Row {
                spacing: 8
                Switch {
                    checked: root.playing
                    onCheckedChanged: root.playing = checked
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Animate drone"
                    color: "#eaeaea"
                    font.pixelSize: 12
                    font.family: root.monoFont
                }
            }
        }
    }
}
