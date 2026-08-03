// Poly3D Examples - filled planar areas, and the edges they can show
//
// The area primitive of Canvas3D. Every shape here is one Poly3D with one ring
// of 2D points; the holes are inner rings, and the wall is the same ring under
// a different plane value.
//
// The top row is the same four shapes throughout - toggle showEdges and watch
// the fill stay exactly as it was, then switch between the two edge modes:
// FaceBorders draws the rings that were handed over, Triangles draws the mesh
// underneath them. The bottom pair is the edgeColor question on a light fill,
// where a factor on the fill has nowhere dark to go.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent

    // Access to camera store passed from parent - null when the scene is
    // rendered on its own rather than from the sandbox.
    property var cameraStore: parent ? parent.cameraStore : null

    // One set of knobs drives every polygon in the top row, so the comparison
    // stays honest.
    property bool edgesOn: edgeSwitch.checked
    property int edgeMode: modeBox.currentIndex === 0 ? Poly3D.FaceBorders
                                                      : Poly3D.Triangles
    property real thickness: thicknessSlider.value

    environment: SceneEnvironment {
        clearColor: "#101820"
        backgroundMode: SceneEnvironment.Color
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 560, 520)
        eulerRotation.x: -46

        Component.onCompleted: {
            if (cameraStore && cameraStore.has("poly3d_camPos"))
                position = JSON.parse(cameraStore.get("poly3d_camPos"))
            if (cameraStore && cameraStore.has("poly3d_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("poly3d_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("poly3d_camPos", JSON.stringify(position))
                cameraStore.set("poly3d_camRot", JSON.stringify(eulerRotation))
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
    }

    // The ground everything else lies on.
    Poly3D {
        vertices: [Qt.vector2d(-520, -340), Qt.vector2d(520, -340),
                   Qt.vector2d(520, 300), Qt.vector2d(-520, 300)]
        color: "#22303c"
        useToonShading: true
    }

    // --- the shape gallery, all under the same edge settings --------------
    //
    // Lifted a hair off the ground: two surfaces at the same height fight over
    // the depth buffer, and Model's depthBias only decides draw order, it does
    // not offset the depth itself.

    // 1 - convex: a hexagon. Its triangulation is a fan, which FaceBorders
    // hides entirely and Triangles shows as spokes.
    Poly3D {
        x: -390
        y: 0.5
        z: -150
        color: "#00d9ff"
        useToonShading: true
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#eafeff"
        vertices: {
            var pts = []
            for (var i = 0; i < 6; ++i) {
                var a = i * Math.PI / 3.0
                pts.push(Qt.vector2d(80 * Math.cos(a), 80 * Math.sin(a)))
            }
            return pts
        }
    }

    // 2 - concave: an L, handed over clockwise on purpose. Winding is
    // normalised while the mesh is built, so it faces up either way.
    Poly3D {
        x: -130
        y: 0.5
        z: -150
        color: "#ff3366"
        useToonShading: true
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#ffe3ea"
        vertices: [Qt.vector2d(-80, -80), Qt.vector2d(-80, 80),
                   Qt.vector2d(-18, 80), Qt.vector2d(-18, 0),
                   Qt.vector2d(80, 0), Qt.vector2d(80, -80)]
    }

    // 3 - concave: a star, the shape a triangle fan cannot fake. The notch at
    // every second point is where FaceBorders and Triangles differ most.
    Poly3D {
        x: 130
        y: 0.5
        z: -150
        color: "#ffd93d"
        useToonShading: true
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#fff8dc"
        vertices: {
            var pts = []
            for (var i = 0; i < 10; ++i) {
                var r = (i % 2 === 0) ? 92 : 38
                var a = -Math.PI / 2 + i * Math.PI / 5.0
                pts.push(Qt.vector2d(r * Math.cos(a), r * Math.sin(a)))
            }
            return pts
        }
    }

    // 4 - two holes cut out of one square. A hole's rim is a ring edge like any
    // other, so FaceBorders outlines the holes too; only the bridges earcut
    // builds between outer ring and holes are hidden.
    Poly3D {
        x: 390
        y: 0.5
        z: -150
        color: "#0f9d9a"
        useToonShading: true
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#dbfffe"
        vertices: [Qt.vector2d(-88, -88), Qt.vector2d(88, -88),
                   Qt.vector2d(88, 88), Qt.vector2d(-88, 88)]
        holes: [
            [Qt.vector2d(-62, -62), Qt.vector2d(-12, -62),
             Qt.vector2d(-12, -12), Qt.vector2d(-62, -12)],
            [Qt.vector2d(14, 14), Qt.vector2d(66, 14), Qt.vector2d(40, 70)]
        ]
    }

    // --- edgeColor against edgeColorFactor, on a light fill ---------------
    //
    // The same shape twice, same thickness, same mode. edgeColorFactor can only
    // scale the fill towards black by a fraction of itself, so on a pale
    // surface it produces pale lines; edgeColor names the colour outright.

    Poly3D {
        x: -130
        y: 0.5
        z: 120
        color: "#e6d2f2"
        useToonShading: true
        showEdges: true
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColorFactor: 0.4
        vertices: [Qt.vector2d(-88, -70), Qt.vector2d(88, -70),
                   Qt.vector2d(58, 70), Qt.vector2d(-58, 70)]
    }

    Poly3D {
        x: 130
        y: 0.5
        z: 120
        color: "#e6d2f2"
        useToonShading: true
        showEdges: true
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#2f3437"
        vertices: [Qt.vector2d(-88, -70), Qt.vector2d(88, -70),
                   Qt.vector2d(58, 70), Qt.vector2d(-58, 70)]
    }

    // --- the same ring standing up ----------------------------------------
    //
    // plane XY makes a wall, and a Box3D in front of it shows that polygons
    // take part in the shadow pass.
    Poly3D {
        z: -330
        plane: Poly3D.XY
        color: "#3d2c5c"
        useToonShading: true
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#c9b8e8"
        vertices: [Qt.vector2d(-200, 0), Qt.vector2d(200, 0),
                   Qt.vector2d(200, 200), Qt.vector2d(-200, 200)]
    }

    Box3D {
        x: 0
        z: -280
        width: 60
        height: 80
        depth: 60
        color: "#e8e8e8"
        useToonShading: true
    }

    // --- controls ---------------------------------------------------------

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: 350
        height: content.implicitHeight + 24
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        border.width: 2

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                spacing: 10

                Switch {
                    id: edgeSwitch
                    text: "showEdges"
                    checked: true
                }

                ComboBox {
                    id: modeBox
                    width: 150
                    model: ["FaceBorders", "Triangles"]
                    currentIndex: 1
                }
            }

            Text {
                text: "edgeThickness: " + view3D.thickness.toFixed(2) + " px"
                color: "#eaeaea"
                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                font.pixelSize: 13
                font.bold: true
            }

            // Well above the 1.0 default on purpose. A rim line is drawn on the
            // inside of the shape only, so at one pixel it is indistinguishable
            // from the silhouette; a diagonal is drawn from both triangles and
            // comes out twice as wide. Three pixels lets the two be compared.
            Slider {
                id: thicknessSlider
                width: parent.width - 8
                from: 0.5
                to: 8.0
                value: 3.0
            }

            Text {
                width: parent.width - 8
                wrapMode: Text.WordWrap
                text: "Top row: four rings under one edge setting. " +
                      "FaceBorders draws only what was handed over - the outer " +
                      "ring and the rims of the holes. Triangles draws the " +
                      "triangulation as well.\n\nTurning showEdges off leaves " +
                      "the fill untouched; the mesh keeps the wider layout it " +
                      "was built with, so turning it back on costs nothing.\n\n" +
                      "Bottom pair: the same pale shape with edgeColorFactor " +
                      "0.4 on the left and edgeColor \"#2f3437\" on the right."
                color: "#8a8a8a"
                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                font.pixelSize: 11
                lineHeight: 1.3
            }
        }
    }
}
