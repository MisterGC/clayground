// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Box3DBody
    \inqmlmodule Clayground.World
    \inherits QtQuick3D.Physics::DynamicRigidBody
    \brief 3D physics-enabled box with visual representation.

    Box3DBody combines a Canvas3D Box3D visual with a dynamic rigid body
    physics shape. It provides a simple way to create physics-enabled 3D objects.

    Example usage:
    \qml
    import Clayground.World

    Box3DBody {
        position: Qt.vector3d(50, 10, 50)
        width: 20; height: 20; depth: 20
        color: "orange"
        density: 10
    }
    \endqml

    \qmlproperty real Box3DBody::width
    \brief Box width in world units.

    \qmlproperty real Box3DBody::height
    \brief Box height in world units.

    \qmlproperty real Box3DBody::depth
    \brief Box depth in world units.

    \qmlproperty color Box3DBody::color
    \brief Box color.

    \qmlproperty int Box3DBody::scaledFace
    \brief Which face to scale (Box3DGeometry enum).

    \qmlproperty vector2d Box3DBody::faceScale
    \brief Scale factor for the scaled face.
*/
import QtQuick
import QtQuick3D
import QtQuick3D.Physics
import Clayground.Canvas3D

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
