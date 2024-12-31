import QtQuick
import QtQuick3D
import QtQuick3D.Physics

DynamicRigidBody {

    property alias width: _box.width
    property alias height: _box.height
    property alias depth: _box.depth
    property alias color: _box.color
    property alias scaledFace: _box.scaledFace
    property alias faceScale: _box.faceScale

    massMode: DynamicRigidBody.CustomDensity
    density: 10

    Box3D {
        id: _box
    }

    physicsMaterial: PhysicsMaterial {
        restitution: 5.6
        dynamicFriction: 1.5
        staticFriction: 0.5
    }

    collisionShapes: BoxShape {
        extents: Qt.vector3d(_box.width, _box.height, _box.depth)
    }
}
