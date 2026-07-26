// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief LabelBatch3D stress: 10k+ instanced SDF labels, moving subset, quality row
// @tags 3D, Canvas3D, Labels
// @category Plugin Demos
//
// Living reference and verification page for LabelBatch3D. Standalone:
//   clayliveloader --sbx LabelBatchStress.qml
// Drive via the inspector: set root.camDist / orbitYaw / orbitPitch, toggle
// root.fly / root.moving, call setCount(n) or applyScenario(name). flagInfo()
// reports counts, shaping time, atlas size and fps.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Canvas3D

Item {
    id: root
    anchors.fill: parent

    // --- inspector-writable controls ---
    property real camDist: 1400
    property real orbitYaw: 0
    property real orbitPitch: -34
    property bool fly: false
    property bool moving: true
    property int sizeMode: LabelBatch3D.Screen
    property int orientation: LabelBatch3D.Billboard
    property bool pill: false
    property int staticCount: 10000
    property int movingCount: 2000

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"
    readonly property var swatch: ["#00d9ff", "#0f9d9a", "#ff3366", "#ffd93d", "#ffffff"]

    // Fly-through: slowly orbit so the perf trace samples a moving camera.
    FrameAnimation {
        running: root.fly
        onTriggered: root.orbitYaw = (elapsedTime * 12) % 360
    }

    // ---- inspector helpers ----
    function flagInfo() {
        return {
            camDist: root.camDist,
            orbitYaw: root.orbitYaw.toFixed(1),
            orbitPitch: root.orbitPitch,
            fly: root.fly,
            moving: root.moving,
            sizeMode: root.sizeMode === LabelBatch3D.Screen ? "Screen" : "World",
            orientation: root.orientation === LabelBatch3D.Billboard ? "Billboard" : "Flat",
            pill: root.pill,
            staticLabels: batch.count,
            staticGlyphs: batch.glyphCount,
            movingLabels: movers.count,
            shapeMsStatic: batch.shapeMsLast.toFixed(2),
            shapeMsMoving: movers.shapeMsLast.toFixed(2),
            atlas: batch.atlasWidth + "x" + batch.atlasHeight,
            fps: view.renderStats ? view.renderStats.fps : -1,
            frameMs: view.renderStats ? view.renderStats.frameTime.toFixed(2) : -1,
            draws: view.renderStats ? view.renderStats.drawCallCount : -1
        }
    }

    function scenarios() {
        return ["overview", "near", "mid", "far", "fly", "flat", "pill", "world"]
    }

    function applyScenario(name) {
        switch (name) {
        case "overview": root.camDist = 1400; root.orbitPitch = -34; root.fly = false; break
        case "near":     root.camDist = 380;  root.orbitPitch = -18; root.fly = false; break
        case "mid":      root.camDist = 900;  root.orbitPitch = -28; root.fly = false; break
        case "far":      root.camDist = 2600; root.orbitPitch = -40; root.fly = false; break
        case "fly":      root.camDist = 1100; root.orbitPitch = -30; root.fly = true;  break
        case "flat":     root.sizeMode = LabelBatch3D.World; root.orientation = LabelBatch3D.Flat
                         root.camDist = 1400; root.orbitPitch = -80; break
        case "world":    root.sizeMode = LabelBatch3D.World; root.orientation = LabelBatch3D.Billboard; break
        case "pill":     root.pill = !root.pill; break
        }
    }

    // ---- static label cloud -------------------------------------------------
    // A near-square grid on the ground; count controls the side. Deterministic
    // text/colors so screenshots are comparable across runs.
    function buildStatic(n) {
        var side = Math.ceil(Math.sqrt(n))
        var spacing = 46
        var half = (side - 1) * spacing * 0.5
        var arr = []
        var k = 0
        for (var r = 0; r < side && k < n; ++r) {
            for (var c = 0; c < side && k < n; ++c, ++k) {
                var x = c * spacing - half
                var z = r * spacing - half
                var y = ((k * 47) % 13) * 3 // slight vertical scatter
                arr.push({
                    position: Qt.vector3d(x, y, z),
                    text: "L" + (1000 + (k % 9000)),
                    color: root.swatch[k % root.swatch.length],
                    size: 18,
                    priority: k % 5,
                    opacity: 1.0
                })
            }
        }
        batch.setLabels(arr)
    }

    function setCount(n) {
        root.staticCount = n
        root.buildStatic(n)
    }

    // ---- moving subset ------------------------------------------------------
    // A ring of labels orbiting the origin, driven each frame through the bulk
    // position path (no re-shaping). Proves update cost stays low.
    property var _movingArr: null
    property real _mt: 0
    function buildMoving(n) {
        var arr = []
        for (var i = 0; i < n; ++i) {
            arr.push({
                position: Qt.vector3d(0, 0, 0),
                text: "M" + i,
                color: "#ffd93d",
                size: 16
            })
        }
        movers.setLabels(arr)
        root._movingArr = new Float32Array(n * 3)
    }

    FrameAnimation {
        running: root.moving
        onTriggered: {
            root._mt = elapsedTime
            var n = root.movingCount
            var a = root._movingArr
            if (!a || a.length < n * 3) return
            for (var i = 0; i < n; ++i) {
                var ang = (i / n) * Math.PI * 2 + elapsedTime * 0.5
                var rad = 520 + (i % 40) * 6
                a[i * 3 + 0] = Math.cos(ang) * rad
                a[i * 3 + 1] = 260 + Math.sin(elapsedTime + i) * 30
                a[i * 3 + 2] = Math.sin(ang) * rad
            }
            movers.updatePositionsBulk(a.buffer, 0)
        }
    }

    Component.onCompleted: {
        root.buildStatic(root.staticCount)
        root.buildMoving(root.movingCount)
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

        Node {
            Node {
                eulerRotation.y: root.orbitYaw
                Node {
                    eulerRotation.x: root.orbitPitch
                    PerspectiveCamera {
                        id: cam
                        position: Qt.vector3d(0, 0, root.camDist)
                        clipFar: 30000
                        clipNear: 1
                    }
                }
            }
        }

        DirectionalLight { eulerRotation.x: -40; eulerRotation.y: -25 }

        // Dark ground for contrast.
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            y: -8
            scale: Qt.vector3d(60, 60, 1)
            materials: PrincipledMaterial { baseColor: "#0d1020"; lighting: PrincipledMaterial.NoLighting }
        }

        // Bright plane + bright line under some labels: depth-punch check. Labels
        // over these must not cut dark holes (NeverDepthDraw).
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            x: -300; y: -6; z: -300
            scale: Qt.vector3d(6, 6, 1)
            materials: PrincipledMaterial { baseColor: "#f2f2f2"; lighting: PrincipledMaterial.NoLighting }
        }
        LineBatch3D {
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            lines: [{ points: [Qt.vector3d(-600, -5, 260), Qt.vector3d(600, -5, 260)],
                      color: "#00d9ff", width: 26, styleId: 0 }]
        }

        // ===== the stress batch =====
        LabelBatch3D {
            id: batch
            viewportSize: Qt.vector2d(view.width, view.height)
            sizeMode: root.sizeMode
            orientation: root.orientation
            halo: true
            pill: root.pill
            pillColor: "#cc16213e"
        }

        // ===== moving subset (bulk position updates) =====
        LabelBatch3D {
            id: movers
            viewportSize: Qt.vector2d(view.width, view.height)
            sizeMode: LabelBatch3D.Screen
            halo: true
        }

        // ===== side-by-side quality row: Label3D vs LabelBatch3D =====
        // Three Label3D callouts at near/mid/far Z, and a LabelBatch3D with the
        // same strings at the same anchors, so crispness can be compared directly.
        Repeater3D {
            model: [
                { z: 120, t: "QUALITY NEAR" },
                { z: -240, t: "QUALITY MID" },
                { z: -700, t: "QUALITY FAR" }
            ]
            delegate: Label3D {
                required property var modelData
                view: view
                camera: cam
                anchorPosition: Qt.vector3d(-560, 220, modelData.z)
                text: modelData.t
                labelStyle.borderColor: "#0f9d9a"
                labelStyle.fontSize: 20
            }
        }
        LabelBatch3D {
            id: qualityBatch
            viewportSize: Qt.vector2d(view.width, view.height)
            sizeMode: LabelBatch3D.Screen
            halo: true
            pill: true
            font.baseSize: 48
            Component.onCompleted: setLabels([
                { position: Qt.vector3d(560, 220, 120),  text: "QUALITY NEAR", color: "#00d9ff", size: 22 },
                { position: Qt.vector3d(560, 220, -240), text: "QUALITY MID",  color: "#00d9ff", size: 22 },
                { position: Qt.vector3d(560, 220, -700), text: "QUALITY FAR",  color: "#00d9ff", size: 22 }
            ])
        }
    }

    // ---- HUD + control panel ----
    PerfHud {
        id: hud
        view3D: view
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
    }

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
                text: "LabelBatch3D stress"
                color: "#00d9ff"; font.pixelSize: 15; font.bold: true; font.family: root.monoFont
            }
            Text {
                text: "labels " + batch.count + "  glyphs " + batch.glyphCount +
                      "\nmoving " + movers.count +
                      "\nshape " + batch.shapeMsLast.toFixed(1) + " ms" +
                      "\natlas " + batch.atlasWidth + "x" + batch.atlasHeight
                color: "#eaeaea"; font.pixelSize: 12; font.family: root.monoFont
            }
            Row {
                spacing: 6
                Repeater {
                    model: [1000, 5000, 10000, 20000]
                    delegate: Button {
                        required property int modelData
                        text: modelData >= 1000 ? (modelData / 1000) + "k" : modelData
                        onClicked: root.setCount(modelData)
                    }
                }
            }
            Row {
                spacing: 8
                Switch { checked: root.fly; onCheckedChanged: root.fly = checked }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Fly"; color: "#eaeaea"; font.pixelSize: 12; font.family: root.monoFont }
                Switch { checked: root.moving; onCheckedChanged: root.moving = checked }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Move"; color: "#eaeaea"; font.pixelSize: 12; font.family: root.monoFont }
                Switch { checked: root.pill; onCheckedChanged: root.pill = checked }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Pill"; color: "#eaeaea"; font.pixelSize: 12; font.family: root.monoFont }
            }
        }
    }
}
