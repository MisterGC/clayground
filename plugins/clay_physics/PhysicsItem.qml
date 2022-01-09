// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import Box2D

Item {
    id: item

    property real pixelPerUnit: 1
    property real xWu: 0
    property real yWu: 0

    // Bidirectional updates as phyics item's x-y coords may be controlled by
    // physics or by canvas world units -> no unidirection binding possible
    onXWuChanged: x = xWu * pixelPerUnit
    onYWuChanged: y = parent ? parent.height - yWu * pixelPerUnit : 0
    onXChanged: xWu = (1/pixelPerUnit) * x;
    onYChanged: yWu = item.parent ? (1/pixelPerUnit) * (item.parent.height - y) : 0
    onPixelPerUnitChanged: {
        x = xWu * pixelPerUnit;
        y = parent ? parent.height - yWu * pixelPerUnit : 0;
    }

    property real widthWu: 1
    property real heightWu: 1

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
        world: typeof physicsWorld !== 'undefined' ? physicsWorld : null
    }
}
