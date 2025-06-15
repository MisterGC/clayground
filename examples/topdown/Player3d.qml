// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Clayground.Canvas3D

CharacterController {
    id: _player

    gravity: Qt.vector3d(0, -9.81, 0)

    // Dimensions for the player
    property real width: 7
    property real height: 7
    property real depth: 7

    // Position player so it sits on the ground (y=0)
    Component.onCompleted: {
        position.y = height * 0.5
    }

    property int maxSpeed: 1

    readonly property real xDirDesire: theGameCtrl.axisX
    movement.x: xDirDesire * maxSpeed
    readonly property real zDirDesire: -theGameCtrl.axisY
    movement.z: zDirDesire * maxSpeed
    Behavior on movement { PropertyAnimation { duration: 100 } }

    // Physical representation
    collisionShapes: [
        CapsuleShape {
        id: capsuleShape
        diameter: _player.width
        height: _player.height
        enableDebugDraw: false
    }
    ]

    // Visual representation
    DefaultMaterial {
        id: _material
        diffuseColor: "orange"
    }

    Box3D
    {
        id: _box
        width: _player.width
        height: _player.height
        depth: _player.depth
        color: "orange"
        useToonShading: true
    }
}
