import QtQuick 2.12
import Box2D 2.0

PhysicsItem
{
    id: theWaypoint

    property string route: ""

    bodyType: Body.Static
    Rectangle { color: "grey"; opacity: 0.4; radius: theRadius.radius; x: theRadius.x; y: theRadius.y; width: 2*radius; height: 2*radius}

    fixtures: [
        Circle {
            id: theRadius
            x: -radius + theWaypoint.width/2
            y: -radius + theWaypoint.height/2
            radius: theWaypoint.width 
            categories: Box.Category1
            collidesWith: Box.Category3 | Box.Category2
            sensor: true
            onBeginContact: {
                console.log("Begin contact!")
            }
        }
    ]
}


