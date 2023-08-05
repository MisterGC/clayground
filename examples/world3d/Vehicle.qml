// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

CharacterController {
    id: _car

    // >0 -> forward, <0 -> backwards
    property int maxSpeed: 10
    property real speedDesire: 0
    property int speed: speedDesire * maxSpeed

    // Used to make turns
    property real maxTurnSpeed: 10
    property real turnDesire: 0
    property int wheelTurn: turnDesire * maxTurnSpeed

    // Physical representation
    collisionShapes: [
        CapsuleShape {
        id: capsuleShape
        diameter: 100
        height: 1
        enableDebugDraw: true
    }
    ]

    // Visual representation
    DefaultMaterial {
        id: _material
        diffuseColor: "yellow"
    }
    Model {
        id: _front
        source: "#Cube"
        scale: Qt.vector3d(.5, .5, .5)
        materials: _material
    }
    Model {
        id: _back
        source: "#Cube"
        scale: Qt.vector3d(.49999, .25, .75)
        position: Qt.vector3d(0, -13, 62)
        materials: _material
    }

    Wheel {position: Qt.vector3d(30, -30, -10) }
    Wheel {position: Qt.vector3d(30, -30, 65); turnEnabled: true }
    Wheel {position: Qt.vector3d(-30, -30, -10) }
    Wheel {position: Qt.vector3d(-30, -30, 65); turnEnabled: true}

    // Movement Behavior
    movement: Qt.vector3d(0, 0, speed)
    Behavior on movement { PropertyAnimation { duration: 100 } }
    Timer {
        id: _carRotator
        interval: 100
        repeat: true
        running: Math.abs(_car.wheelTurn) > 0 && Math.abs(_car.speed) > 0
        onTriggered: {
            let delta = _car.speed < 0 ?  _car.wheelTurn : -_car.wheelTurn
            _car.eulerRotation.y = (_car.eulerRotation.y + delta) % 360
        }
    }
    Behavior on eulerRotation.y {
        NumberAnimation{duration: 100}
    }

    component Wheel: Model {
        id: _wheel
        source: "#Cylinder"
        eulerRotation.z: 90
        property bool turnEnabled: false
        eulerRotation.y: turnEnabled ? 0 : _car.wheelTurn * 5
        castsShadows: true

        Timer {
            id: _wheelRotator
            property bool forward: _car.speedDesire <= 0
            interval: 100
            repeat: true
            running: Math.abs(_car.speedDesire) > 0
            onTriggered: {
                let delta = forward ? -60 : 60
                _wheel.eulerRotation.x = (_wheel.eulerRotation.x + delta) % 360
            }
        }
        scale: Qt.vector3d(.25, .1, .25)
        materials: DefaultMaterial { diffuseColor: "red"}

        Model {
            id: _profile
            source: "#Cube"
            scale: Qt.vector3d(.25, .5, .5)
            position: Qt.vector3d(25, -15, -50)
            materials: PrincipledMaterial {
                baseColor: "black"
            }
            castsShadows: true
        }
    }
}
