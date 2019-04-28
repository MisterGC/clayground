import QtQuick 2.12
import Box2D 2.0

VisualizedBoxBody
{
    id: thePlayer
    bodyType: Body.Dynamic
    color: "#3fa4c8"
    bullet: true
    property real maxVelo: 8
    categories: Box.Category2
    collidesWith: Box.Category1
    property bool isPlayer: true
    property int energy: 10000

    function moveUp() { body.linearVelocity.y = -maxVelo; }
    function moveDown() { body.linearVelocity.y = maxVelo; }
    function moveLeft() { body.linearVelocity.x = -maxVelo; }
    function moveRight() { body.linearVelocity.x = maxVelo; }

    function stopUp() { if (body.linearVelocity.y < 0) body.linearVelocity.y = 0; }
    function stopDown() { if (body.linearVelocity.y > 0) body.linearVelocity.y = 0; }
    function stopLeft() { if (body.linearVelocity.x < 0) body.linearVelocity.x = 0; }
    function stopRight() { if (body.linearVelocity.x > 0) body.linearVelocity.x = 0; }

    ScalingText
    {
        parent: thePlayer.parent
        x: thePlayer.x - width/2
        y: thePlayer.y - height * 1.1
        z: 99
        text: "Here I am!"
        color: "#3fa4c8"
        pixelPerUnit: thePlayer.pixelPerUnit
        fontSizeWu: 0.5
    }
}
