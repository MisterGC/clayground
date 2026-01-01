// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype RectBoxBody
    \inqmlmodule Clayground.Physics
    \inherits PhysicsItem
    \brief Rectangle-shaped physics body with visual representation.

    RectBoxBody combines a visual Rectangle with a Box2D box fixture,
    providing an easy way to create rectangular physics objects.

    Example usage:
    \qml
    import Clayground.Physics
    import Box2D

    RectBoxBody {
        xWu: 5; yWu: 10
        widthWu: 2; heightWu: 1
        color: "blue"
        bodyType: Body.Dynamic
        density: 1
        friction: 0.3
        restitution: 0.5
    }
    \endqml

    \qmlproperty Fixture RectBoxBody::fixture
    \brief The Box2D box fixture.

    \qmlproperty color RectBoxBody::color
    \brief Fill color of the rectangle.

    \qmlproperty real RectBoxBody::radius
    \brief Corner radius of the rectangle.

    \qmlproperty Border RectBoxBody::border
    \brief Border properties of the rectangle.

    \qmlproperty real RectBoxBody::density
    \brief Fixture density affecting mass.

    \qmlproperty real RectBoxBody::friction
    \brief Friction coefficient (0-1).

    \qmlproperty real RectBoxBody::restitution
    \brief Bounciness coefficient (0-1).

    \qmlproperty bool RectBoxBody::sensor
    \brief If true, detects collisions without physical response.

    \qmlproperty int RectBoxBody::categories
    \brief Collision category bits.

    \qmlproperty int RectBoxBody::collidesWith
    \brief Collision mask bits.

    \qmlproperty int RectBoxBody::groupIndex
    \brief Collision group index.
*/
import QtQuick
import Box2D

PhysicsItem {
    id: theItem

    property alias fixture: box
    property alias color: rect.color
    property alias radius: rect.radius
    property alias border: rect.border

    // Box properties
    property alias density: box.density
    property alias friction: box.friction
    property alias restitution: box.restitution
    property alias sensor: box.sensor
    property alias categories: box.categories
    property alias collidesWith: box.collidesWith
    property alias groupIndex: box.groupIndex

    Rectangle {id: rect; color: theItem.color; anchors.fill: parent }

    fixtures: [
        Box {
            id: box
            width: theItem.width
            height: theItem.height
        }
    ]
}
