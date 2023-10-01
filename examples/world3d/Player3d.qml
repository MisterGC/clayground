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

    readonly property real xDirDesire: theGameCtrl.axisX
    movement.x: xDirDesire * maxSpeed
    readonly property real zDirDesire: -theGameCtrl.axisY
    movement.z: zDirDesire * maxSpeed
    Behavior on movement { PropertyAnimation { duration: 100 } }

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
        diffuseColor: "orange"
    }
    Model {
        id: _front
        source: "#Cube"
        //scale: Qt.vector3d(.5, .5, .5)
        materials: _material
    }


}
