// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Verification-only sandbox: renders a handful of the real neoncity cars
// (CarSystem) on a minimal two-road graph so the low-poly car model - body,
// rear cabin, cyan front window, four wheels, varied palette - can be inspected
// up close without the streaming city. A feeder dead-ends into a spine at the
// origin, so feeder cars MUST turn onto the spine there (turning evidence)
// while spine cars pass straight through. Not part of the shipped demo.

import QtQuick
import QtQuick3D

Item {
    id: root
    anchors.fill: parent

    // Road-surface height the cars ride on (wheels touch this plane).
    readonly property real roadY: 0.8

    readonly property var cityData: ({
        seed: 7,
        roads: [
            { id: 0, kind: "spine", axis: "h", width: 9.0,
              centerline: [{ x: -60, z: 0 }, { x: 60, z: 0 }] },
            { id: 1, kind: "feeder", axis: "v", width: 5.6,
              centerline: [{ x: 0, z: -60 }, { x: 0, z: 0 }] }
        ]
    })

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#140a24" }
            GradientStop { position: 0.7; color: "#3d1a54" }
            GradientStop { position: 1.0; color: "#0a0a16" }
        }
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        PerspectiveCamera {
            id: cam
            position: Qt.vector3d(7.5, 3.2, 13.0)
            fieldOfView: 42
            clipFar: 4000
            Component.onCompleted: lookAt(Qt.vector3d(4.0, 1.0, 3.4))
        }

        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -60
            color: Qt.rgba(1.0, 0.92, 0.98, 1.0)
            brightness: 1.0
            ambientColor: Qt.rgba(0.30, 0.28, 0.40, 1.0)
        }

        // Dark road plate, just under the wheel-contact plane.
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(1.4, 1.4, 1)
            y: root.roadY - 0.02
            materials: PrincipledMaterial { baseColor: "#101018"; roughness: 1.0 }
        }

        // The real car system. baseSpeed is low so cars are easy to trace and
        // screenshot as they steer through the junction at the origin.
        CarSystem {
            id: cars
            cityData: root.cityData
            roadY: root.roadY
            baseSpeed: 12.0
            carCount: 24
            showCars: true
            connectorLayer: null
            manager: null
        }
    }

    function flagInfo() {
        return { activeCars: cars.activeCars, carW: cars._carW,
                 carL: cars._carL, carH: cars._carH }
    }
}
