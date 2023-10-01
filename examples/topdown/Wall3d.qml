// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick3D
import QtQuick3D.Physics

StaticRigidBody {
    collisionShapes: BoxShape { id: boxShape }
    readonly property Model model: _wallElementModel
    Model {
        id: _wallElementModel
        source: "#Cube"
        materials: PrincipledMaterial {
            baseColor: Qt.rgba(0, 0, 1, 1)
        }
        castsShadows: true
    }
}
