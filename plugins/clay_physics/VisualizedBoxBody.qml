// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0

PhysicsItem {
    id: theVisuBoxBody

    property alias fixture: box

    property string source: ""
    property color color: "transparent"
    property var image: null

    // Box properties
    property alias density: box.density
    property alias friction: box.friction
    property alias restitution: box.restitution
    property alias sensor: box.sensor
    property alias categories: box.categories
    property alias collidesWith: box.collidesWith
    property alias groupIndex: box.groupIndex

    Loader {
        anchors.fill: parent
        sourceComponent: theVisuBoxBody.source !== "" ? theImgComp : theRectComp
        onSourceComponentChanged: {
            theVisuBoxBody.image = theVisuBoxBody.source !== "" ? item : null
        }
    }

    Component {
        id: theImgComp
        Image { source: theVisuBoxBody.source; anchors.fill: parent }
    }

    Component {
        id: theRectComp
        Rectangle { color: theVisuBoxBody.color; anchors.fill: parent }
    }

    fixtures: [
        Box {
            id: box
            width: theVisuBoxBody.width
            height: theVisuBoxBody.height
        }
    ]
}

