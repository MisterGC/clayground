// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Box3DBody
    \inqmlmodule Clayground.World
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

    \sa ClayWorld3d, Box3D
*/
import QtQuick
import QtQuick3D
import QtQuick3D.Physics
import Clayground.Canvas3D

DynamicRigidBody {

    /*!
        \qmlproperty real Box3DBody::width
        \brief Box width in world units.
    */
    property alias width: _box.width

    /*!
        \qmlproperty real Box3DBody::height
        \brief Box height in world units.
    */
    property alias height: _box.height

    /*!
        \qmlproperty real Box3DBody::depth
        \brief Box depth in world units.
    */
    property alias depth: _box.depth

    /*!
        \qmlproperty color Box3DBody::color
        \brief Box color.
    */
    property alias color: _box.color

    /*!
        \qmlproperty int Box3DBody::scaledFace
        \brief Which face to scale (Box3DGeometry enum).
    */
    property alias scaledFace: _box.scaledFace

    /*!
        \qmlproperty vector2d Box3DBody::faceScale
        \brief Scale factor for the scaled face.
    */
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
