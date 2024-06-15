// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick3D
import QtQuick3D.Physics
import Clayground.World

StaticRigidBody {
    id: _wall

    collisionShapes: BoxShape { id: boxShape }
    readonly property Model model: _wallElementModel

    // world scene loader uses dimensions not scaling values
    property alias dimensions: _scaleByDims.dimensions
    ScaleByDimensions {
        id: _scaleByDims
        target: _wall
        origDimensions: cCUBE_MODEL_DIMENSIONS
    }
    property alias color: _wallMaterial.baseColor

    // Either set the y components here or use the
    // initializer cfg in the scene SVG
    dimensions.y: 10
    position.y: dimensions.y * .5

    Model {
        id: _wallElementModel
        source: "#Cube"
        materials: PrincipledMaterial {
            id: _wallMaterial
            baseColor: Qt.rgba(0, 0, 1, 1)
        }
        castsShadows: true
    }
}
