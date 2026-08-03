// Poly3D Examples - filled planar areas, and the edges they can show
//
// The area primitive of Canvas3D. Every shape here is one Poly3D with one ring
// of 2D points; the holes are inner rings, and the wall is the same ring under
// a different plane value.
//
// The top row is the same four shapes throughout - toggle showEdges and watch
// the fill stay exactly as it was, then switch between the two edge modes:
// FaceBorders draws the rings that were handed over, Triangles draws the mesh
// underneath them. The middle pair is the edgeColor question on a light fill,
// where a factor on the fill has nowhere dark to go.
//
// The front row is the same rings under extrude: the flat area becomes a prism,
// holes become courtyards, and the rightmost pair is an extruded square beside
// a Box3D of the same size and the same edgeThickness - their borders are meant
// to be indistinguishable.

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
    property real prismHeight: heightSlider.value
    // The documented way to animate a prism's height: the geometry is built
    // once and the node is scaled, so nothing is retriangulated per frame and
    // the edge lines - measured in pixels - keep their weight throughout.
    // Driving extrude itself from an animation would rebuild the mesh on every
    // frame instead, which is the mistake this is here to make unnecessary.
    property real heightScale: growSwitch.checked ? grow.value : 1.0

    QtObject {
        id: grow
        property real value: 1.0
    }

    SequentialAnimation {
        running: growSwitch.checked
        loops: Animation.Infinite
        NumberAnimation {
            target: grow; property: "value"
            from: 0.15; to: 1.0; duration: 1400; easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: grow; property: "value"
            from: 1.0; to: 0.15; duration: 1400; easing.type: Easing.InOutQuad
        }
    }

    environment: SceneEnvironment {
        clearColor: "#101820"
        backgroundMode: SceneEnvironment.Color
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(30, 800, 960)
        eulerRotation.x: -40

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
        vertices: [Qt.vector2d(-620, -340), Qt.vector2d(660, -340),
                   Qt.vector2d(660, 520), Qt.vector2d(-620, 520)]
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

    // --- extrude: the same rings as solids ---------------------------------
    //
    // A prism, not a lid on a block: the walls follow every ring the polygon
    // has, so the courtyard in the middle one goes all the way through. Each
    // wall carries its own normal, which is what keeps the hexagon reading as
    // six flat faces under toon shading rather than as a cylinder.

    // 5 - the L again, standing up. Its notch stays a notch all the way up.
    Poly3D {
        x: -280
        z: 380
        scale.y: view3D.heightScale
        color: "#ff3366"
        useToonShading: true
        extrude: view3D.prismHeight
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#ffe3ea"
        vertices: [Qt.vector2d(-80, -80), Qt.vector2d(-80, 80),
                   Qt.vector2d(-18, 80), Qt.vector2d(-18, 0),
                   Qt.vector2d(80, 0), Qt.vector2d(80, -80)]
    }

    // 6 - a ring with a courtyard: the hole gets walls of its own, facing in.
    Poly3D {
        x: -30
        z: 380
        scale.y: view3D.heightScale
        color: "#0f9d9a"
        useToonShading: true
        extrude: view3D.prismHeight
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#dbfffe"
        vertices: [Qt.vector2d(-88, -88), Qt.vector2d(88, -88),
                   Qt.vector2d(88, 88), Qt.vector2d(-88, 88)]
        holes: [[Qt.vector2d(-44, -44), Qt.vector2d(44, -44),
                 Qt.vector2d(44, 44), Qt.vector2d(-44, 44)]]
    }

    // 7 - a hexagonal column: the facet test.
    Poly3D {
        x: 220
        z: 380
        scale.y: view3D.heightScale
        color: "#00d9ff"
        useToonShading: true
        extrude: view3D.prismHeight
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

    // 8 - the calibration pair: a Box3D and an extruded square, same size, same
    // edgeThickness. An extruded polygon's border is a line two of its own
    // surfaces share, so each draws half of it - exactly what a box does - and
    // the two come out the same weight. Anything else here is a bug.
    Box3D {
        x: 430
        z: 380
        scale.y: view3D.heightScale
        width: 120
        height: view3D.prismHeight
        depth: 120
        color: "#ffd93d"
        useToonShading: true
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#4a3d0d"
    }

    Poly3D {
        x: 570
        z: 380
        scale.y: view3D.heightScale
        color: "#ffd93d"
        useToonShading: true
        extrude: view3D.prismHeight
        showEdges: view3D.edgesOn
        edgeMode: view3D.edgeMode
        edgeThickness: view3D.thickness
        edgeColor: "#4a3d0d"
        vertices: [Qt.vector2d(-60, -60), Qt.vector2d(60, -60),
                   Qt.vector2d(60, 60), Qt.vector2d(-60, 60)]
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
                text: "extrude: " + view3D.prismHeight.toFixed(0)
                color: "#eaeaea"
                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                font.pixelSize: 13
                font.bold: true
            }

            // Front row only. 0 puts every prism back to the flat area it was
            // built from - the same mesh, not a flattened solid.
            Slider {
                id: heightSlider
                width: parent.width - 8
                from: 0.0
                to: 200.0
                value: 90.0
            }

            Switch {
                id: growSwitch
                text: "animate height (scale.y)"
                checked: false
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
                      "Middle pair: the same pale shape with edgeColorFactor " +
                      "0.4 on the left and edgeColor \"#2f3437\" on the right.\n\n" +
                      "Front row: the same rings extruded. The rightmost pair " +
                      "is a Box3D and an extruded Poly3D of the same size - " +
                      "their borders read the same at every thickness. The " +
                      "switch animates scale.y rather than extrude, which is " +
                      "the way to move a prism's height without rebuilding it."
                color: "#8a8a8a"
                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                font.pixelSize: 11
                lineHeight: 1.3
            }
        }
    }
}
