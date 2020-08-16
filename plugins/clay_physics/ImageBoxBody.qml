// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0

PhysicsItem {
    id: theItem

    property alias fixture: box

    // Image properties
    property alias source: img.source
    property alias fillMode: img.fillMode
    property alias mirror: img.mirror

    // Box properties
    property alias density: box.density
    property alias friction: box.friction
    property alias restitution: box.restitution
    property alias sensor: box.sensor
    property alias categories: box.categories
    property alias collidesWith: box.collidesWith
    property alias groupIndex: box.groupIndex

    Image {id: img; source: theItem.source; anchors.fill: parent }

    fixtures: [
        Box {
            id: box
            width: theItem.width
            height: theItem.height
        }
    ]
}
