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
            // Unique word textures per path label (shared across repeats).
            pathTextures: {
                "CLAY STREET": streetLabel.uniqueTextureCount,
                "TEAL AVENUE": avenueLabel.uniqueTextureCount,
                "LOOP ROAD": loopLabel.uniqueTextureCount
            },
            // Glyph-mode comparison labels. glyphBatchActive proves pay-per-use:
            // word-mode labels above allocate no glyph batch (all false here only
            // for those); the three glyph labels below each own a lazy batch.
            glyph: {
                streetActive: streetGlyph.glyphBatchActive,
                loopActive: loopGlyph.glyphBatchActive,
                tightActive: tightGlyph.glyphBatchActive,
                tightSkipped: tightGlyph.skippedPlacements,
                streetSkipped: streetGlyph.skippedPlacements,
                loopSkipped: loopGlyph.skippedPlacements,
                // Word-mode labels must never spin up a glyph batch.
                wordStreetActive: streetLabel.glyphBatchActive
            },
            fps: view.renderStats ? view.renderStats.fps : -1
        }
    }

    function scenarios() {
        return ["overview", "angled", "near", "far", "readability", "leader",
                "paths-top", "paths-near", "paths-flip",
                "glyph-street", "glyph-loop", "glyph-tight"]
    }

    function applyScenario(name) {
        switch (name) {
        case "overview":    root.camDist = 950;  root.orbitYaw = 0;   root.orbitPitch = -22; break
        case "angled":      root.camDist = 950;  root.orbitYaw = 38;  root.orbitPitch = -28; break
        case "near":        root.camDist = 480;  root.orbitYaw = 0;   root.orbitPitch = -14; break
        case "far":         root.camDist = 1800; root.orbitYaw = 0;   root.orbitPitch = -14; break
        case "readability": root.camDist = 620;  root.orbitYaw = -30; root.orbitPitch = -10; break
        case "leader":      root.camDist = 620;  root.orbitYaw = 0;   root.orbitPitch = -16; break
        // Path-label views look straight down at the road area (z ~ +600).
        case "paths-top":   root.camDist = 1200; root.orbitYaw = 0;   root.orbitPitch = -88; root.camTargetZ = 600; break
        case "paths-near":  root.camDist = 520;  root.orbitYaw = 0;   root.orbitPitch = -80; root.camTargetZ = 520; break
        case "paths-flip":  root.camDist = 780;  root.orbitYaw = 0;   root.orbitPitch = -88; root.camTargetZ = 760; break
        // Word vs glyph comparison views (each frames a word road and its glyph
        // twin one lane below).
        case "glyph-street": root.camDist = 620;  root.orbitYaw = 0;  root.orbitPitch = -88; root.camTargetZ = 470; break
        case "glyph-loop":   root.camDist = 760;  root.orbitYaw = 0;  root.orbitPitch = -88; root.camTargetZ = 1000; break
        case "glyph-tight":  root.camDist = 520;  root.orbitYaw = 0;  root.orbitPitch = -88; root.camTargetZ = 1120; break
        }
    }

    // The road area sits south of the callouts; the orbit rig can slide its look
    // target along Z so the top-down path scenarios frame it without overlap.
    property real camTargetZ: 0

    // Sampled bezier-ish polylines for the road network. A cubic through four
    // control points, sampled into a smooth polyline the labels can ride.
    function bezier(p0, p1, p2, p3, segs) {
        var pts = []
        for (var i = 0; i <= segs; ++i) {
            var t = i / segs
            var u = 1 - t
            var a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            pts.push(Qt.vector3d(a * p0.x + b * p1.x + c * p2.x + d * p3.x, 0.4,
                                 a * p0.z + b * p1.z + c * p2.z + d * p3.z))
        }
        return pts
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

        // Orbit rig: look-target pivot -> yaw -> pitch -> camera at local +Z.
        // The look target slides along Z (camTargetZ) so the top-down path
        // scenarios can frame the road area without moving the callout section.
        Node {
            z: root.camTargetZ
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

        // ==================================================================
        // PathLabel3D road area (south of the callouts, best seen top-down via
        // the "paths-top" / "paths-near" / "paths-flip" scenarios).
        // ==================================================================
        // Dark tarmac slab under the roads for contrast.
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            y: 0.1
            z: 720
            scale: Qt.vector3d(20, 15, 1)
            materials: PrincipledMaterial { baseColor: "#0d1020"; lighting: PrincipledMaterial.NoLighting }
        }

        // Three roads drawn as subtly-styled polylines; each carries a name.
        LineBatch3D {
            id: roads
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.World
            styles: [{ dash: [0, 0], capRound: true, opacity: 0.9, color: "#0f9d9a" }]
            Component.onCompleted: {
                roads.lines = [
                    // 0: gently curved arterial -> single centered street name
                    { points: root.bezier(Qt.vector3d(-780, 0, 380), Qt.vector3d(-300, 0, 300),
                                          Qt.vector3d(240, 0, 560), Qt.vector3d(760, 0, 460), 32),
                      color: "#0f9d9a", width: 26, styleId: 0 },
                    // 1: long straightish avenue -> repeated name
                    { points: root.bezier(Qt.vector3d(-780, 0, 720), Qt.vector3d(-260, 0, 660),
                                          Qt.vector3d(260, 0, 700), Qt.vector3d(780, 0, 640), 32),
                      color: "#0f9d9a", width: 22, styleId: 0 },
                    // 2: doubled-back hairpin -> flip-to-read proof
                    { points: root.bezier(Qt.vector3d(-560, 0, 900), Qt.vector3d(360, 0, 840),
                                          Qt.vector3d(360, 0, 1000), Qt.vector3d(-560, 0, 960), 40),
                      color: "#0f9d9a", width: 22, styleId: 0 },
                    // 3: S-curve twin of road 0, one lane below -> glyph CLAY STREET
                    { points: root.bezier(Qt.vector3d(-780, 0, 470), Qt.vector3d(-300, 0, 390),
                                          Qt.vector3d(240, 0, 650), Qt.vector3d(760, 0, 550), 32),
                      color: "#0f9d9a", width: 26, styleId: 0 },
                    // 4: hairpin below road 2 -> glyph LOOP ROAD, correct on both legs
                    { points: root.bezier(Qt.vector3d(-540, 0, 1060), Qt.vector3d(420, 0, 1060),
                                          Qt.vector3d(420, 0, 1210), Qt.vector3d(-540, 0, 1210), 44),
                      color: "#0f9d9a", width: 22, styleId: 0 },
                    // 5: tight teardrop loop -> curvature guard skips the placement
                    { points: root.bezier(Qt.vector3d(-10, 0, 1340), Qt.vector3d(180, 0, 1250),
                                          Qt.vector3d(180, 0, 1430), Qt.vector3d(10, 0, 1340), 40),
                      color: "#ff3366", width: 18, styleId: 0 }
                ]
            }
        }

        // Road 0: one street name centered on the curve.
        PathLabel3D {
            id: streetLabel
            lines: roads
            lineId: 0
            text: "CLAY STREET"
            worldHeight: 34
            labelStyle.textColor: "#00d9ff"
        }
        // Road 1: the same name stamped repeatedly along a long avenue.
        PathLabel3D {
            id: avenueLabel
            lines: roads
            lineId: 1
            text: "TEAL AVENUE"
            worldHeight: 30
            repeatEvery: 620
            labelStyle.textColor: "#ffd93d"
        }
        // Road 2: hairpin that doubles back - repeated so each leg is its own
        // placement and flips independently, proving text never goes upside-down.
        PathLabel3D {
            id: loopLabel
            lines: roads
            lineId: 2
            text: "LOOP ROAD"
            worldHeight: 30
            repeatEvery: 700
            labelStyle.textColor: "#ff3366"
        }

        // ---- glyph-placement twins (per-glyph text-on-curve) ----
        // Road 3: same S-curve as road 0, one lane below. Compare directly with
        // streetLabel above: glyph mode hugs the curve per glyph, not per word.
        PathLabel3D {
            id: streetGlyph
            lines: roads
            lineId: 3
            text: "CLAY STREET"
            worldHeight: 34
            glyphPlacement: true
            labelStyle.textColor: "#00d9ff"
        }
        // Road 4: hairpin. Each leg is its own placement (repeatEvery) and must
        // read "LOOP ROAD" upright and in correct word order on BOTH legs.
        PathLabel3D {
            id: loopGlyph
            lines: roads
            lineId: 4
            text: "LOOP ROAD"
            worldHeight: 30
            repeatEvery: 900
            glyphPlacement: true
            labelStyle.textColor: "#ff3366"
        }
        // Road 5: a tight half-loop. The curvature guard drops the placement
        // rather than drawing it wrapped; skippedPlacements reports it.
        PathLabel3D {
            id: tightGlyph
            lines: roads
            lineId: 5
            text: "TIGHT BEND"
            worldHeight: 28
            glyphPlacement: true
            labelStyle.textColor: "#ffd93d"
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
