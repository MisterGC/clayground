// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Physics 1.0

VisualizedBoxBody
{
    id: thePlayer
    bodyType: Body.Dynamic
    color: "#3fa4c8"
    bullet: true
    property real maxVelo: 25
    categories: Box.Category2
    collidesWith: Box.Category1
    property bool isPlayer: true
    property int energy: 10000
    readonly property int maxEnergy: 10000
    opacity: energy/maxEnergy
    fixedRotation: false

    function moveUp() { body.linearVelocity.y = -maxVelo; }
    function moveDown() { body.linearVelocity.y = maxVelo; }
    function moveLeft() { body.linearVelocity.x = -maxVelo; }
    function moveRight() { body.linearVelocity.x = maxVelo; }

    function stopUp() { if (body.linearVelocity.y < 0) body.linearVelocity.y = 0; }
    function stopDown() { if (body.linearVelocity.y > 0) body.linearVelocity.y = 0; }
    function stopLeft() { if (body.linearVelocity.x < 0) body.linearVelocity.x = 0; }
    function stopRight() { if (body.linearVelocity.x > 0) body.linearVelocity.x = 0; }
}
