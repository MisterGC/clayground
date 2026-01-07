// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ImageBoxBody
    \inqmlmodule Clayground.Physics
    \inherits PhysicsItem
    \brief Image-based physics body with Box2D box collision.

    ImageBoxBody displays an image and provides a rectangular box fixture
    for physics collision. Useful for sprites that need physics interaction.

    Example usage:
    \qml
    import Clayground.Physics
    import Box2D

    ImageBoxBody {
        source: "coin.png"
        xWu: 10; yWu: 5
        widthWu: 0.5; heightWu: 0.5
        bodyType: Body.Static
        sensor: true
    }
    \endqml

    \qmlproperty Fixture ImageBoxBody::fixture
    \brief The Box2D box fixture.

    \qmlproperty url ImageBoxBody::source
    \brief Image source URL.

    \qmlproperty Image.FillMode ImageBoxBody::fillMode
    \brief How the image fills its area.

    \qmlproperty bool ImageBoxBody::mirror
    \brief Mirror the image horizontally.

    \qmlproperty real ImageBoxBody::tileWidthWu
    \brief Tile width for repeating images in world units.

    \qmlproperty real ImageBoxBody::tileHeightWu
    \brief Tile height for repeating images in world units.

    \qmlproperty real ImageBoxBody::density
    \brief Fixture density affecting mass.

    \qmlproperty real ImageBoxBody::friction
    \brief Friction coefficient (0-1).

    \qmlproperty real ImageBoxBody::restitution
    \brief Bounciness coefficient (0-1).

    \qmlproperty bool ImageBoxBody::sensor
    \brief If true, detects collisions without physical response.

    \qmlproperty int ImageBoxBody::categories
    \brief Collision category bits.

    \qmlproperty int ImageBoxBody::collidesWith
    \brief Collision mask bits.

    \qmlproperty int ImageBoxBody::groupIndex
    \brief Collision group index.
*/
import QtQuick
import Box2D

PhysicsItem {
    id: theItem

    property alias fixture: box
    property alias source: img.source
    property alias fillMode: img.fillMode
    property alias mirror: img.mirror
    property real tileWidthWu: widthWu
    property real tileHeightWu: heightWu

    // Box properties
    property alias density: box.density
    property alias friction: box.friction
    property alias restitution: box.restitution
    property alias sensor: box.sensor
    property alias categories: box.categories
    property alias collidesWith: box.collidesWith
    property alias groupIndex: box.groupIndex

    Image {
        id: img

        anchors.fill: parent
        sourceSize.width: theItem.pixelPerUnit * theItem.tileWidthWu
        sourceSize.height:  theItem.pixelPerUnit * theItem.tileHeightWu
    }

    fixtures: [
        Box {
            id: box
            width: theItem.width
            height: theItem.height
        }
    ]
}
