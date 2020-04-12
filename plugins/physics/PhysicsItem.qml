// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0

Item {
    id: item

    property real pixelPerUnit: 1
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 1
    property real heightWu: 1

    x: xWu * pixelPerUnit
    y: parent.height - yWu * pixelPerUnit
    width: widthWu * pixelPerUnit
    height: heightWu * pixelPerUnit
    property alias body: itemBody

    // Body properties
    property alias world: itemBody.world
    property alias linearDamping: itemBody.linearDamping
    property alias angularDamping: itemBody.angularDamping
    property alias bodyType: itemBody.bodyType
    property alias bullet: itemBody.bullet
    property alias sleepingAllowed: itemBody.sleepingAllowed
    property alias fixedRotation: itemBody.fixedRotation
    property alias active: itemBody.active
    property alias awake: itemBody.awake
    property alias linearVelocity: itemBody.linearVelocity
    property alias angularVelocity: itemBody.angularVelocity
    property alias fixtures: itemBody.fixtures
    property alias gravityScale: itemBody.gravityScale

    Body {
        id: itemBody

        target: item
        world: physicsWorld
    }
}
