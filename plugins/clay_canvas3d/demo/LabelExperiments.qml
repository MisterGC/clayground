// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Label rendering experiments: Item2D vs sourceItem-texture, billboard, path
// @tags 3D, Canvas3D, Labels, Research
// @category Plugin Demos
//
// Research bench for professional 3D label support. Two label families:
//   A) camera-facing callout (text + pill background anchored to an entity)
//   B) along-path street-name style text lying flat on the floor.
// Compares the two carrier mechanisms Qt Quick 3D offers:
//   item2d  - a plain QtQuick Item parented under a Node (Quick3D Item2D)
//   texture - Texture{ sourceItem } on an unlit quad Model
//
// Drive it via the inspector: set root.demoMode / labelTech / camDist / etc,
// or applyScenario(name). flagInfo() reports live renderStats for cost.
// Standalone: clayliveloader --sbx LabelExperiments.qml

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Canvas3D

Item {
    id: root
    anchors.fill: parent

    // --- control surface (inspector-writable) ---
    property string demoMode: "compare"   // compare | stress | billboard | pathlbl | readability
    property string labelTech: "item2d"   // item2d | texture (used by stress/billboard)
    property real camDist: 450
    property real orbitYaw: 0
    property real orbitPitch: -12
    property int stressCount: 150
    property bool billboardOn: true
    property bool screenConstant: false
    property bool hiResTexture: false     // author sourceItem at 2x for crispness test
    property string labelText: "REACTOR CORE 42"

    // Per-frame tick so billboard / screen-constant bindings re-evaluate.
    property real tick: 0
    FrameAnimation { running: true; onTriggered: root.tick = elapsedTime }

    // Continuous camera spin: forces genuine per-frame re-rendering (a static
    // billboard binding returns the same value each tick and never marks the
    // View3D dirty, so fps looks idle). Turn on for any perf measurement.
    property bool spin: false
    NumberAnimation on orbitYaw {
        running: root.spin
        from: 0; to: 360; duration: 8000; loops: Animation.Infinite
    }

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // ---- inspector helpers ----
    function flagInfo() {
        var s = view.renderStats
        return {
            demoMode: root.demoMode,
            labelTech: root.labelTech,
            camDist: root.camDist,
            stressCount: root.demoMode === "stress" ? root.stressCount : 0,
            billboardOn: root.billboardOn,
            screenConstant: root.screenConstant,
            hiResTexture: root.hiResTexture,
            devicePixelRatio: Screen.devicePixelRatio,
            fps: s ? s.fps : -1,
            frameMs: s ? Number(s.frameTime).toFixed(2) : "-",
            renderMs: s ? Number(s.renderTime).toFixed(2) : "-",
            gpuMs: s ? Number(s.lastCompletedGpuTime).toFixed(2) : "-",
            draws: s ? s.drawCallCount : -1,
            verts: s ? s.drawVertexCount : -1
        }
    }

    function scenarios() {
        return ["compare-near", "compare-mid", "compare-far",
                "stress-item2d", "stress-texture",
                "billboard", "pathlbl", "readability",
                "texture-hires-far"]
    }

    function applyScenario(name) {
        switch (name) {
        case "compare-near":  root.demoMode = "compare"; root.camDist = 340; root.orbitYaw = 0;  root.orbitPitch = -8;  break
        case "compare-mid":   root.demoMode = "compare"; root.camDist = 750; root.orbitYaw = 0;  root.orbitPitch = -8;  break
        case "compare-far":   root.demoMode = "compare"; root.camDist = 1600; root.orbitYaw = 0; root.orbitPitch = -8;  break
        case "texture-hires-far": root.demoMode = "compare"; root.hiResTexture = true; root.camDist = 340; root.orbitPitch = -8; break
        case "stress-item2d": root.demoMode = "stress"; root.labelTech = "item2d";  root.stressCount = 150; root.camDist = 1400; root.orbitPitch = -35; break
        case "stress-texture":root.demoMode = "stress"; root.labelTech = "texture"; root.stressCount = 150; root.camDist = 1400; root.orbitPitch = -35; break
        case "billboard":     root.demoMode = "billboard"; root.billboardOn = true; root.camDist = 500; root.orbitPitch = -20; break
        case "pathlbl":       root.demoMode = "pathlbl"; root.camDist = 900; root.orbitPitch = -89; root.orbitYaw = 0; break
        case "readability":   root.demoMode = "readability"; root.camDist = 350; root.orbitPitch = -6; break
        }
    }

    // Billboard: rotate a node so its +Z faces the camera. Reads root.tick so
    // the binding recomputes every frame while the camera flies.
    function faceCam(px, py, pz) {
        var c = cam.scenePosition
        var dx = c.x - px, dy = c.y - py, dz = c.z - pz
        var yaw = Math.atan2(dx, dz) * 180 / Math.PI
        var horiz = Math.sqrt(dx * dx + dz * dz)
        var pitch = -Math.atan2(dy, horiz) * 180 / Math.PI
        return Qt.vector3d(pitch, yaw, 0)
    }

    // Screen-constant scale: on-screen size of a perspective object is ~1/dist,
    // so scaling by dist keeps it constant. k picks the nominal on-screen size.
    function constScale(px, py, pz, k) {
        var c = cam.scenePosition
        var dx = c.x - px, dy = c.y - py, dz = c.z - pz
        return Math.sqrt(dx * dx + dy * dy + dz * dz) * k
    }

    // ======================================================================
    // Reusable 2D label content (the "pill"): rounded background + haloed text.
    // Used identically as an Item2D child AND as a Texture.sourceItem.
    // ======================================================================
    component Pill: Rectangle {
        property string txt: "LABEL"
        property color pillColor: "#cc16213e"
        property color accent: "#00d9ff"
        property int fontPx: 22
        property bool halo: true
        implicitWidth: label.implicitWidth + 28
        implicitHeight: label.implicitHeight + 16
        radius: height * 0.5
        color: pillColor
        border.color: accent
        border.width: 2
        Text {
            id: label
            anchors.centerIn: parent
            text: parent.txt
            color: "#ffffff"
            font.family: root.monoFont
            font.pixelSize: parent.fontPx
            font.bold: true
            style: parent.halo ? Text.Outline : Text.Normal
            styleColor: "#000000"
        }
    }

    // ======================================================================
    // Scene
    // ======================================================================
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

        // Orbit rig: yaw pivot -> pitch pivot -> camera at local +Z. Camera
        // always looks at the scene origin; distance is the camera's local z.
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

        // --- depth-cue reference geometry (always present) ---
        Model {
            source: "#Rectangle"
            visible: root.demoMode === "pathlbl" || root.demoMode === "stress"
            eulerRotation.x: -90
            scale: Qt.vector3d(40, 40, 1)
            materials: PrincipledMaterial { baseColor: "#1c2233"; lighting: PrincipledMaterial.NoLighting }
        }

        // ==================================================================
        // MODE: compare  - one Item2D callout (left) vs one texture callout
        // (right), identical pill content, with a reference box between them.
        // ==================================================================
        Node {
            visible: root.demoMode === "compare" || root.demoMode === "readability"

            // center reference box for depth
            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.6, 0.6, 0.6)
                materials: PrincipledMaterial { baseColor: "#0f9d9a" }
            }

            // ---- LEFT: Item2D route ----
            Node {
                x: -160; y: 40
                eulerRotation: { root.tick; return root.billboardOn ? root.faceCam(x, y, 0) : Qt.vector3d(0, 0, 0) }
                scale: {
                    root.tick
                    var s = root.screenConstant ? root.constScale(x, y, 0, 0.0016) : 0.5
                    return Qt.vector3d(s, s, s)
                }
                // A QtQuick Item as a direct child of a Node => Quick3D Item2D.
                Pill {
                    x: -implicitWidth / 2
                    y: -implicitHeight / 2
                    txt: "I2D  " + root.labelText
                    accent: "#00d9ff"
                }
            }

            // ---- RIGHT: Texture(sourceItem) route ----
            Node {
                x: 160; y: 40
                eulerRotation: { root.tick; return root.billboardOn ? root.faceCam(x, y, 0) : Qt.vector3d(0, 0, 0) }
                scale: {
                    root.tick
                    var s = root.screenConstant ? root.constScale(x, y, 0, 0.0016) : 1.0
                    return Qt.vector3d(s, s, s)
                }
                TextureQuad {
                    txt: "TEX  " + root.labelText
                    accent: "#ffd93d"
                    hiRes: root.hiResTexture
                }
            }
        }

        // ==================================================================
        // MODE: readability - the two callouts sit over a bright and a dark
        // patch to judge halo/pill contrast. Patches added here.
        // ==================================================================
        Node {
            visible: root.demoMode === "readability"
            Model { source: "#Rectangle"; x: -160; y: 40; z: -30; scale: Qt.vector3d(2.4, 1.2, 1)
                materials: PrincipledMaterial { baseColor: "#f2f2f2"; lighting: PrincipledMaterial.NoLighting } }
            Model { source: "#Rectangle"; x: 160; y: 40; z: -30; scale: Qt.vector3d(2.4, 1.2, 1)
                materials: PrincipledMaterial { baseColor: "#050608"; lighting: PrincipledMaterial.NoLighting } }
        }

        // ==================================================================
        // MODE: stress - N callouts in a grid, item2d or texture, to measure
        // per-label frame cost. Text carries the index so each label is unique
        // (worst case for the texture route: no texture sharing).
        // ==================================================================
        // Item2D stress grid (active only for that tech, so cost is isolated).
        Repeater3D {
            model: (root.demoMode === "stress" && root.labelTech === "item2d") ? root.stressCount : 0
            delegate: Node {
                id: i2dCell
                required property int index
                readonly property int side: Math.ceil(Math.sqrt(root.stressCount))
                readonly property real gx: (index % side - (side - 1) / 2) * 220
                readonly property real gz: (Math.floor(index / side) - (side - 1) / 2) * 220
                x: gx; y: 60; z: gz
                scale: Qt.vector3d(0.4, 0.4, 0.4)
                eulerRotation: { root.tick; return root.billboardOn ? root.faceCam(gx, 60, gz) : Qt.vector3d(0, 0, 0) }
                // NB: an Item2D child's `parent` is an internal Quick3D wrapper,
                // not this Node - reach the delegate via its id instead.
                Pill {
                    x: -implicitWidth / 2; y: -implicitHeight / 2
                    txt: "LBL-" + i2dCell.index
                    fontPx: 20
                }
            }
        }
        // Texture stress grid.
        Repeater3D {
            model: (root.demoMode === "stress" && root.labelTech === "texture") ? root.stressCount : 0
            delegate: Node {
                id: texCell
                required property int index
                readonly property int side: Math.ceil(Math.sqrt(root.stressCount))
                readonly property real gx: (index % side - (side - 1) / 2) * 220
                readonly property real gz: (Math.floor(index / side) - (side - 1) / 2) * 220
                x: gx; y: 60; z: gz
                eulerRotation: { root.tick; return root.billboardOn ? root.faceCam(gx, 60, gz) : Qt.vector3d(0, 0, 0) }
                TextureQuad {
                    scale: Qt.vector3d(0.8, 0.8, 0.8)
                    txt: "LBL-" + texCell.index
                }
            }
        }

        // ==================================================================
        // MODE: pathlbl - family B feasibility. A curved polyline on the floor
        // (LineBatch3D) with per-word quads laid flat, oriented along the
        // tangent, using positionAt()/pathLength(). Viewed top-down.
        // ==================================================================
        LineBatch3D {
            id: pathBatch
            visible: root.demoMode === "pathlbl"
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.World
            styles: [{ dash: [0, 0], capRound: true, opacity: 1.0, color: "#0f9d9a" }]
            Component.onCompleted: {
                lines = [{
                    points: [Qt.vector3d(-700, 0.5, 200), Qt.vector3d(-300, 0.5, -150),
                             Qt.vector3d(150, 0.5, -180), Qt.vector3d(600, 0.5, 120)],
                    color: "#0f9d9a", width: 10, styleId: 0
                }]
                root.rebuildPathLabels()
            }
        }

        Repeater3D {
            id: pathLabelRep
            model: root.demoMode === "pathlbl" ? root.pathWords.length : 0
            delegate: Node {
                id: pathCell
                required property int index
                property var w: root.pathWords[index]
                position: w.pos
                // Outer node yaws about the world vertical (Y) to follow the
                // path tangent; inner node tips the upright quad -90 about X so
                // it lies flat on the floor. Splitting the two rotations keeps
                // the euler order unambiguous (flatten-then-yaw).
                eulerRotation.y: 90 - w.yaw
                Node {
                    eulerRotation.x: -90
                    TextureQuad {
                        txt: pathCell.w.text
                        accent: "#ffd93d"
                        scale: Qt.vector3d(0.7, 0.7, 0.7)
                    }
                }
            }
        }

        PerfHud {
            id: hud
            view3D: view
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
        }
    }

    // ---- family B: sample word positions + tangents along the path ----
    property var pathWords: []
    function rebuildPathLabels() {
        var words = ["CLAY", "STREET", "AVE", "NORTH"]
        var total = pathBatch.pathLength(0)
        var arr = []
        for (var i = 0; i < words.length; ++i) {
            var d = total * (i + 0.5) / words.length
            var p = pathBatch.positionAt(0, d)
            // tangent by finite difference along the path
            var pa = pathBatch.positionAt(0, Math.max(0, d - 8))
            var pb = pathBatch.positionAt(0, Math.min(total, d + 8))
            var yaw = Math.atan2(pb.x - pa.x, pb.z - pa.z) * 180 / Math.PI
            arr.push({ text: words[i], pos: Qt.vector3d(p.x, 1.0, p.z), yaw: yaw })
        }
        root.pathWords = arr
    }

    // ======================================================================
    // Texture-route quad: an unlit blended plane whose baseColorMap is a live
    // QtQuick Pill rendered offscreen via Texture.sourceItem. Declared as a
    // component so both compare/stress/path can reuse it. The #Rectangle mesh
    // is a 100x100 XY plane centered at origin, facing +Z.
    // ======================================================================
    component TextureQuad: Model {
        id: quad
        property string txt: "LABEL"
        property color accent: "#00d9ff"
        property bool hiRes: false
        property real oversample: hiRes ? 2.0 : 1.0
        source: "#Rectangle"
        // scale plane to the pill's aspect; unit = world units per source px.
        // Matches the Item2D left label's node scale so both routes render at
        // the same on-screen size for a fair crispness comparison.
        readonly property real unit: 0.5
        // Dividing by oversample keeps the world size fixed while a hi-res
        // sourceItem packs more texels behind the same quad (crispness test).
        scale: Qt.vector3d(src.width / 100 * unit / oversample,
                           src.height / 100 * unit / oversample, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            alphaMode: PrincipledMaterial.Blend
            baseColorMap: Texture {
                sourceItem: Pill {
                    id: src
                    txt: quad.txt
                    accent: quad.accent
                    fontPx: Math.round(22 * quad.oversample)
                    // when oversampling, keep world size the same by shrinking
                    // via the quad scale unit that reads src.width (auto).
                }
            }
        }
    }

    // ---- minimal control panel ----
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        width: col.implicitWidth + 24
        height: col.implicitHeight + 24
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            Text { text: "Label Experiments"; color: "#00d9ff"; font.bold: true
                   font.family: root.monoFont; font.pixelSize: 14 }
            Text { text: "mode: " + root.demoMode + "   tech: " + root.labelTech
                   color: "#eaeaea"; font.family: root.monoFont; font.pixelSize: 12 }
            Text { text: "camDist: " + root.camDist.toFixed(0) + "   dpr: " + Screen.devicePixelRatio
                   color: "#8a8a8a"; font.family: root.monoFont; font.pixelSize: 12 }
        }
    }
}
