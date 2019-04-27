import QtQuick 2.12
import Box2D 2.0

VisualizedBoxBody
{
    bodyType: Body.Dynamic
    color: "green"
    bullet: true

    function moveUp() { body.linearVelocity.y = -10; }
    function moveDown() { body.linearVelocity.y = 10; }
    function moveRight() { body.linearVelocity.x = 10; }
    function moveLeft() { body.linearVelocity.x = -10; }
    function stop() { body.linearVelocity = {"x":0, "y":0}; }
}
