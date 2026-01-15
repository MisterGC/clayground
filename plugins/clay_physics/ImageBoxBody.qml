// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ImageBoxBody
    \inqmlmodule Clayground.Physics
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

    \sa PhysicsItem, RectBoxBody
*/
import QtQuick
import Box2D

PhysicsItem {
    id: theItem

    /*!
        \qmlproperty Fixture ImageBoxBody::fixture
        \brief The Box2D box fixture.
    */
    property alias fixture: box

    /*!
        \qmlproperty url ImageBoxBody::source
        \brief Image source URL.
    */
    property alias source: img.source

    /*!
        \qmlproperty Image.FillMode ImageBoxBody::fillMode
        \brief How the image fills its area.
    */
    property alias fillMode: img.fillMode

    /*!
        \qmlproperty bool ImageBoxBody::mirror
        \brief Mirror the image horizontally.
    */
    property alias mirror: img.mirror

    /*!
        \qmlproperty real ImageBoxBody::tileWidthWu
        \brief Tile width for repeating images in world units.
    */
    property real tileWidthWu: widthWu

    /*!
        \qmlproperty real ImageBoxBody::tileHeightWu
        \brief Tile height for repeating images in world units.
    */
    property real tileHeightWu: heightWu

    /*!
        \qmlproperty real ImageBoxBody::density
        \brief Fixture density affecting mass.
    */
    property alias density: box.density

    /*!
        \qmlproperty real ImageBoxBody::friction
        \brief Friction coefficient (0-1).
    */
    property alias friction: box.friction

    /*!
        \qmlproperty real ImageBoxBody::restitution
        \brief Bounciness coefficient (0-1).
    */
    property alias restitution: box.restitution

    /*!
        \qmlproperty bool ImageBoxBody::sensor
        \brief If true, detects collisions without physical response.
    */
    property alias sensor: box.sensor

    /*!
        \qmlproperty int ImageBoxBody::categories
        \brief Collision category bits.
    */
    property alias categories: box.categories

    /*!
        \qmlproperty int ImageBoxBody::collidesWith
        \brief Collision mask bits.
    */
    property alias collidesWith: box.collidesWith

    /*!
        \qmlproperty int ImageBoxBody::groupIndex
        \brief Collision group index.
    */
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
