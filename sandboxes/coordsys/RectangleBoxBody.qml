import QtQuick 2.0
import Box2D 2.0

Rectangle {
    id: rectangle

    property alias body: boxBody
    property alias fixture: box

    property real pixelPerUnit: parent.pixelPerUnit
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 1
    property real heightWu: 1

    x: xWu * pixelPerUnit
    y: parent.height - yWu * pixelPerUnit
    width: widthWu * pixelPerUnit
    height: heightWu * pixelPerUnit

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
    property alias density: box.density
    property alias friction: box.friction
    property alias restitution: box.restitution
    property alias sensor: box.sensor
    property alias categories: box.categories
    property alias collidesWith: box.collidesWith
    property alias groupIndex: box.groupIndex

    Body {
        id: boxBody

        target: rectangle

        Box {
            id: box

            width: rectangle.width
            height: rectangle.height
        }
    }
}

