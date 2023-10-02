// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Clayground.World

CharacterController {
    id: _player

    // world scene loader uses dimensions not scaling values
    property alias dimensions: _scaleByDims.dimensions
    ScaleByDimensions {
        id: _scaleByDims
        target: _player
        origDimensions: cCUBE_MODEL_DIMENSIONS
    }


    // Either set the y components here or use the
    // initializer cfg in the scene SVG
    dimensions.y: 10
    position.y: dimensions.y * .5

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
        materials: _material
    }
}
