// Poly3D Examples - filled planar areas: convex, concave, holes, three planes
//
// The area primitive of Canvas3D. Every shape here is one Poly3D with one ring
// of 2D points; the holes are inner rings, and the walls are the same ring
// under a different plane value.

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent

    // Access to camera store passed from parent - null when the scene is
    // rendered on its own rather than from the sandbox.
    property var cameraStore: parent ? parent.cameraStore : null

    environment: SceneEnvironment {
        clearColor: "#101820"
        backgroundMode: SceneEnvironment.Color
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 520, 560)
        eulerRotation.x: -42

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
        vertices: [Qt.vector2d(-520, -320), Qt.vector2d(520, -320),
                   Qt.vector2d(520, 320), Qt.vector2d(-520, 320)]
        color: "#22303c"
        useToonShading: true
    }

    // 1 - convex: a hexagon. Lifted a hair off the ground: two surfaces at the
    // same height fight over the depth buffer, and Model's depthBias only
    // decides draw order, it does not offset the depth itself.
    Poly3D {
        x: -360
        y: 0.5
        color: "#00d9ff"
        useToonShading: true
        vertices: {
            var pts = []
            for (var i = 0; i < 6; ++i) {
                var a = i * Math.PI / 3.0
                pts.push(Qt.vector2d(90 * Math.cos(a), 90 * Math.sin(a)))
            }
            return pts
        }
    }

    // 2 - concave: an L, handed over clockwise on purpose. Winding is
    // normalised while the mesh is built, so it faces up either way.
    Poly3D {
        x: -120
        y: 0.5
        color: "#ff3366"
        useToonShading: true
        vertices: [Qt.vector2d(-90, -90), Qt.vector2d(-90, 90),
                   Qt.vector2d(-20, 90), Qt.vector2d(-20, 0),
                   Qt.vector2d(90, 0), Qt.vector2d(90, -90)]
    }

    // 3 - concave: a star, the shape a triangle fan cannot fake.
    Poly3D {
        x: 130
        y: 0.5
        color: "#ffd93d"
        useToonShading: true
        vertices: {
            var pts = []
            for (var i = 0; i < 10; ++i) {
                var r = (i % 2 === 0) ? 105 : 42
                var a = -Math.PI / 2 + i * Math.PI / 5.0
                pts.push(Qt.vector2d(r * Math.cos(a), r * Math.sin(a)))
            }
            return pts
        }
    }

    // 4 - two holes cut out of one square.
    Poly3D {
        x: 380
        y: 0.5
        color: "#0f9d9a"
        useToonShading: true
        vertices: [Qt.vector2d(-95, -95), Qt.vector2d(95, -95),
                   Qt.vector2d(95, 95), Qt.vector2d(-95, 95)]
        holes: [
            [Qt.vector2d(-70, -70), Qt.vector2d(-15, -70),
             Qt.vector2d(-15, -15), Qt.vector2d(-70, -15)],
            [Qt.vector2d(15, 15), Qt.vector2d(70, 15), Qt.vector2d(42, 75)]
        ]
    }

    // 5 - the same ring standing up: plane XY makes a wall, and a Box3D in
    // front of it shows the polygons take part in the shadow pass.
    Poly3D {
        z: -300
        plane: Poly3D.XY
        color: "#3d2c5c"
        useToonShading: true
        vertices: [Qt.vector2d(-200, 0), Qt.vector2d(200, 0),
                   Qt.vector2d(200, 220), Qt.vector2d(-200, 220)]
    }

    Box3D {
        z: -180
        width: 70
        height: 90
        depth: 70
        color: "#e8e8e8"
        useToonShading: true
    }
}
