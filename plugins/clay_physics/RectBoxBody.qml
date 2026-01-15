// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype RectBoxBody
    \inqmlmodule Clayground.Physics
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

    \sa PhysicsItem, ImageBoxBody
*/
import QtQuick
import Box2D

PhysicsItem {
    id: theItem

    /*!
        \qmlproperty Fixture RectBoxBody::fixture
        \brief The Box2D box fixture.
    */
    property alias fixture: box

    /*!
        \qmlproperty color RectBoxBody::color
        \brief Fill color of the rectangle.
    */
    property alias color: rect.color

    /*!
        \qmlproperty real RectBoxBody::radius
        \brief Corner radius of the rectangle.
    */
    property alias radius: rect.radius

    /*!
        \qmlproperty Border RectBoxBody::border
        \brief Border properties of the rectangle.
    */
    property alias border: rect.border

    /*!
        \qmlproperty real RectBoxBody::density
        \brief Fixture density affecting mass.
    */
    property alias density: box.density

    /*!
        \qmlproperty real RectBoxBody::friction
        \brief Friction coefficient (0-1).
    */
    property alias friction: box.friction

    /*!
        \qmlproperty real RectBoxBody::restitution
        \brief Bounciness coefficient (0-1).
    */
    property alias restitution: box.restitution

    /*!
        \qmlproperty bool RectBoxBody::sensor
        \brief If true, detects collisions without physical response.
    */
    property alias sensor: box.sensor

    /*!
        \qmlproperty int RectBoxBody::categories
        \brief Collision category bits.
    */
    property alias categories: box.categories

    /*!
        \qmlproperty int RectBoxBody::collidesWith
        \brief Collision mask bits.
    */
    property alias collidesWith: box.collidesWith

    /*!
        \qmlproperty int RectBoxBody::groupIndex
        \brief Collision group index.
    */
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
