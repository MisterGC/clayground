import QtQuick 2.0
import Box2D 2.0

Image {
    id: theImage

    property alias body: boxBody
    property alias fixture: circle

    property real pixelPerUnit: 1
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 1
    property real heightWu: 1

    x: xWu * pixelPerUnit
    y: parent.height - yWu * pixelPerUnit
    width: widthWu * pixelPerUnit
    height: heightWu * pixelPerUnit

    // Placeholder visu properties
    property alias color: thePlaceholder.color

    // Body properties
    property alias world: boxBody.world
    property alias linearDamping: boxBody.linearDamping
    property alias angularDamping: boxBody.angularDamping
    property alias bodyType: boxBody.bodyType
    property alias bullet: boxBody.bullet
    property alias sleepingAllowed: boxBody.sleepingAllowed
    property alias fixedRotation: boxBody.fixedRotation
    property alias active: boxBody.active
    property alias awake: boxBody.awake
    property alias linearVelocity: boxBody.linearVelocity
    property alias angularVelocity: boxBody.angularVelocity
    property alias fixtures: boxBody.fixtures
    property alias gravityScale: boxBody.gravityScale

    // Box properties
    property alias density: circle.density
    property alias friction: circle.friction
    property alias restitution: circle.restitution
    property alias sensor: circle.sensor
    property alias categories: circle.categories
    property alias collidesWith: circle.collidesWith
    property alias groupIndex: circle.groupIndex

    Rectangle {
        id: thePlaceholder
        anchors.centerIn: parent
        visible: theImage.source == ""
        width: parent.width
        height: parent.height
        //radius: width/2
    }

    Body {
        id: boxBody

        target: theImage

        Circle {
            id: circle
            radius: theImage.width/2
        }
    }
}

