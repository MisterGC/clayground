// (c) Clayground Contributors - zlib license, see "LICENSE" file

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
