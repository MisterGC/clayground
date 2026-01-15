// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype PhysicsItem
    \inqmlmodule Clayground.Physics
    \brief Base component for physics-enabled items with world unit support.

    PhysicsItem provides the foundation for all physics-enabled components,
    handling bidirectional coordinate synchronization between world units and
    screen pixels, and wrapping a Box2D Body.

    Example usage:
    \qml
    import Clayground.Physics
    import Box2D

    PhysicsItem {
        xWu: 5; yWu: 10
        widthWu: 2; heightWu: 1
        pixelPerUnit: 50
        bodyType: Body.Dynamic
    }
    \endqml

    \sa RectBoxBody, ImageBoxBody, VisualizedPolyBody
*/
import QtQuick
import Box2D

Item {
    id: item

    /*!
        \qmlproperty real PhysicsItem::pixelPerUnit
        \brief Conversion factor between pixels and world units.
    */
    property real pixelPerUnit: 1

    /*!
        \qmlproperty real PhysicsItem::xWu
        \brief X position in world units.
    */
    property real xWu: 0

    /*!
        \qmlproperty real PhysicsItem::yWu
        \brief Y position in world units.
    */
    property real yWu: 0

    // Bidirectional updates as phyics item's x-y coords may be controlled by
    // physics or by canvas world units -> no unidirection binding possible
    onXWuChanged: x = xWu * pixelPerUnit
    onYWuChanged: y = parent ? parent.height - yWu * pixelPerUnit : 0
    onXChanged: xWu = (1/pixelPerUnit) * x;
    onYChanged: yWu = item.parent ? (1/pixelPerUnit) * (item.parent.height - y) : 0
    onPixelPerUnitChanged: {
        x = xWu * pixelPerUnit;
        y = parent ? parent.height - yWu * pixelPerUnit : 0;
    }

    /*!
        \qmlproperty real PhysicsItem::widthWu
        \brief Width in world units.
    */
    property real widthWu: 1

    /*!
        \qmlproperty real PhysicsItem::heightWu
        \brief Height in world units.
    */
    property real heightWu: 1

    width: widthWu * pixelPerUnit
    height: heightWu * pixelPerUnit

    /*!
        \qmlproperty Body PhysicsItem::body
        \brief The Box2D body instance.
    */
    property alias body: itemBody

    /*!
        \qmlproperty World PhysicsItem::world
        \brief Physics world reference. Auto-detected if physicsWorld exists in context.
    */
    property alias world: itemBody.world

    /*!
        \qmlproperty real PhysicsItem::linearDamping
        \brief Linear motion damping coefficient.
    */
    property alias linearDamping: itemBody.linearDamping

    /*!
        \qmlproperty real PhysicsItem::angularDamping
        \brief Angular motion damping coefficient.
    */
    property alias angularDamping: itemBody.angularDamping

    /*!
        \qmlproperty Body.BodyType PhysicsItem::bodyType
        \brief Body type: Body.Static, Body.Kinematic, or Body.Dynamic.
    */
    property alias bodyType: itemBody.bodyType

    /*!
        \qmlproperty bool PhysicsItem::bullet
        \brief Enable continuous collision detection for fast-moving objects.
    */
    property alias bullet: itemBody.bullet

    /*!
        \qmlproperty bool PhysicsItem::sleepingAllowed
        \brief Whether the body can sleep when inactive.
    */
    property alias sleepingAllowed: itemBody.sleepingAllowed

    /*!
        \qmlproperty bool PhysicsItem::fixedRotation
        \brief Prevent the body from rotating.
    */
    property alias fixedRotation: itemBody.fixedRotation

    /*!
        \qmlproperty bool PhysicsItem::active
        \brief Whether the body is active in the physics simulation.
    */
    property alias active: itemBody.active

    /*!
        \qmlproperty bool PhysicsItem::awake
        \brief Whether the body is awake (not sleeping).
    */
    property alias awake: itemBody.awake

    /*!
        \qmlproperty point PhysicsItem::linearVelocity
        \brief Linear velocity vector (x, y).
    */
    property alias linearVelocity: itemBody.linearVelocity

    /*!
        \qmlproperty real PhysicsItem::angularVelocity
        \brief Angular velocity in radians per second.
    */
    property alias angularVelocity: itemBody.angularVelocity

    /*!
        \qmlproperty list PhysicsItem::fixtures
        \brief List of fixtures attached to this body.
    */
    property alias fixtures: itemBody.fixtures

    /*!
        \qmlproperty real PhysicsItem::gravityScale
        \brief Gravity effect multiplier for this body.
    */
    property alias gravityScale: itemBody.gravityScale

    Body {
        id: itemBody

        target: item
        world: typeof physicsWorld !== 'undefined' ? physicsWorld : null
    }
}
