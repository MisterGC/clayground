// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype CircleBody
    \inqmlmodule Clayground.Physics
    \brief Circle-shaped physics body with visual representation.

    CircleBody combines a round visual with a Box2D circle fixture. Unlike a
    box fixture it has no corners to snag on, which is what makes it the
    collider of choice for characters and projectiles moving along walls.

    Example usage:
    \qml
    import Clayground.Physics
    import Box2D

    CircleBody {
        xWu: 5; yWu: 5
        radiusWu: 0.5
        color: "red"
        bodyType: Body.Dynamic
        density: 1
        friction: 0.3
        restitution: 0.5
    }
    \endqml

    \note \c xWu and \c yWu address the bounding box's corner, exactly as they
    do for RectBoxBody - not the circle's centre. The centre sits \c radiusWu
    away from both.

    \sa PhysicsItem, RectBoxBody
*/
import QtQuick
import Box2D

PhysicsItem {
    id: theItem

    /*!
        \qmlproperty real CircleBody::radiusWu
        \brief Radius in world units.
    */
    property real radiusWu: 0.5

    // Box2D's round shape is a circle, not an ellipse, so the item is kept
    // square: visual and fixture both read radiusWu and cannot drift apart.
    widthWu: radiusWu * 2
    heightWu: radiusWu * 2

    /*!
        \qmlproperty Fixture CircleBody::fixture
        \brief The Box2D circle fixture.
    */
    property alias fixture: circle

    /*!
        \qmlproperty color CircleBody::color
        \brief Fill color of the circle.
    */
    property alias color: disc.color

    /*!
        \qmlproperty Border CircleBody::border
        \brief Border properties of the circle.
    */
    property alias border: disc.border

    /*!
        \qmlproperty real CircleBody::density
        \brief Fixture density affecting mass.
    */
    property alias density: circle.density

    /*!
        \qmlproperty real CircleBody::friction
        \brief Friction coefficient (0-1).
    */
    property alias friction: circle.friction

    /*!
        \qmlproperty real CircleBody::restitution
        \brief Bounciness coefficient (0-1).
    */
    property alias restitution: circle.restitution

    /*!
        \qmlproperty bool CircleBody::sensor
        \brief If true, detects collisions without physical response.
    */
    property alias sensor: circle.sensor

    /*!
        \qmlproperty int CircleBody::categories
        \brief Collision category bits.
    */
    property alias categories: circle.categories

    /*!
        \qmlproperty int CircleBody::collidesWith
        \brief Collision mask bits.
    */
    property alias collidesWith: circle.collidesWith

    /*!
        \qmlproperty int CircleBody::groupIndex
        \brief Collision group index.
    */
    property alias groupIndex: circle.groupIndex

    Rectangle {
        id: disc
        anchors.fill: parent
        radius: width * 0.5
    }

    fixtures: [
        Circle {
            id: circle
            // Box2D places a circle by its centre in the item's local pixel
            // frame - unlike Box, which takes a corner plus a size. The item
            // is square, so the centre is its middle.
            x: theItem.width * 0.5
            y: theItem.height * 0.5
            radius: theItem.width * 0.5
        }
    ]
}
